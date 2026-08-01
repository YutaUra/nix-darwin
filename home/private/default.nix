{ pkgs, config, ... }:
let
  # moshi-hook は nixpkgs に無いためビルド済みバイナリを自前パッケージ化している（pkgs/moshi-hook.nix）。
  moshi-hook = pkgs.callPackage ../../pkgs/moshi-hook.nix { };
in
{
  # private 固有の home.packages
  home.packages = (with pkgs; [
    # AI コーディングエージェント用のターミナルマルチプレクサ
    herdr

    # iOS の Moshi アプリから SSH ハンドシェイク後に UDP へ切り替えて接続するための mosh。
    # 回線切替（Wi-Fi↔モバイル）やスリープをまたいでもセッションが維持される。
    mosh
  ]) ++ [
    # Claude Code の hook(PreToolUse/Notification/Stop) から呼ばれ、承認待ちやターン完了を
    # iPhone の Moshi アプリへ通知する Go デーモン。ペアリング token は macOS Keychain に保存される。
    moshi-hook
  ];

  # ~/.aws/config を宣言的に管理する（private マシンのみ）。
  # アカウント ID と SSO スタート URL は AWS 公式見解では秘密情報ではないため
  # 平文で commit している。認証情報そのもの（SSO トークン等）は
  # ~/.aws/sso/ 以下に置かれ home-manager 管理外のまま。
  programs.awscli = {
    enable = true;
    settings = {
      "profile 147997134905" = {
        sso_session = "147997134905";
        sso_account_id = "147997134905";
        sso_role_name = "AdministratorAccess";
        region = "ap-northeast-1";
        output = "json";
      };
      "sso-session 147997134905" = {
        sso_start_url = "https://d-95674b959d.awsapps.com/start";
        sso_region = "ap-northeast-1";
        sso_registration_scopes = "sso:account:access";
      };
      "sso-session irodas" = {
        sso_start_url = "https://irodas.awsapps.com/start/#";
        sso_region = "ap-northeast-1";
        sso_registration_scopes = "sso:account:access";
      };
      "profile irodas-bio" = {
        sso_session = "irodas";
        sso_account_id = "118107592413";
        sso_role_name = "AdministratorAccess";
        region = "ap-northeast-1";
        output = "json";
      };
      "profile irodas-dev" = {
        sso_session = "irodas";
        sso_account_id = "362976989817";
        sso_role_name = "AdministratorAccess";
        region = "ap-northeast-1";
        output = "json";
      };
      "profile irodas-rpa-stg" = {
        sso_session = "irodas";
        sso_account_id = "657498838285";
        sso_role_name = "StgChutoroAdministratorAccess";
        region = "ap-northeast-1";
        output = "json";
      };
      "profile irodas-rpa-prod" = {
        sso_session = "irodas";
        sso_account_id = "905223169255";
        sso_role_name = "ProdChutoroAdministratorAccess";
        region = "ap-northeast-1";
        output = "json";
      };
    };
  };

  # brew services を使わず launchd で moshi-hook デーモン（Unix socket + Moshi への WebSocket bridge）を常駐させる。
  # brew services の代替として宣言的に管理することで、インストールから起動まで nix に一元化できる。
  launchd.agents.moshi-hook = {
    enable = true;
    config = {
      ProgramArguments = [ "${moshi-hook}/bin/moshi-hook" "serve" ];
      RunAtLoad = true;
      KeepAlive = true;
      # moshi-hook serve は context 取得で herdr/tmux/zellij を呼ぶため、profile の bin を PATH に通す。
      EnvironmentVariables = {
        PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/moshi-hook.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/moshi-hook.log";
    };
  };

  # Claude Code 起動時に 1Password から秘密を環境変数として注入する。
  # リポジトリ直下に .env.template（op:// 参照のみを書いたファイル）がある場合のみ発火する。
  #
  # 単なる export ではなく op run を挟む理由:
  #   op run は子プロセスの stdout/stderr をスキャンし、秘密値が現れると
  #   <concealed by 1Password> へ置換する。これにより秘密が Claude の
  #   コンテキスト（= Anthropic へ送信されるデータ）に載ることを防ぐ。
  #   export や direnv ではこのマスキングが効かない。
  #
  # env -u OP_SERVICE_ACCOUNT_TOKEN している理由:
  #   op run は自身の環境変数を子へ継承させるため、そのままだとトークンが
  #   claude のプロセスに残る。すると claude が op read を直接叩いて vault 全体を
  #   読めてしまい（= マスキングを迂回できる）op run を挟む意味が失われる。
  #   exec 直前に剥がすことでこの経路を塞ぐ。
  #
  # git ルートで打ち切る理由:
  #   親を無制限に遡ると ~/.env.template がホーム配下全域で発火し、無関係な
  #   プロジェクトへ秘密が混入する。秘密はリポジトリ単位で管理する規約を関数側で強制する。
  #
  # トークンを Keychain に置く理由:
  #   ~/.zshrc.local 等で export すると全プロセスの環境に常駐し、上記 env -u が無意味になる。
  #   平文ファイルも避けたいため、moshi-hook のペアリング token と同じく Keychain に寄せる。
  programs.zsh.initContent = ''
    claude() {
      local root env_file token

      root="$(git rev-parse --show-toplevel 2>/dev/null)"
      env_file="$root/.env.template"

      if [[ -z "$root" || ! -f "$env_file" ]]; then
        command claude "$@"
        return $?
      fi

      token="$(security find-generic-password -w -s claude-code-op-token 2>/dev/null)"
      if [[ -z "$token" ]]; then
        # 秘密なしでも作業自体は続行できるため、失敗させず警告に留める。
        print -u2 "warning: claude-code-op-token が Keychain に無いため 1Password 注入をスキップします"
        command claude "$@"
        return $?
      fi

      OP_SERVICE_ACCOUNT_TOKEN="$token" \
        op run --env-file="$env_file" -- \
        env -u OP_SERVICE_ACCOUNT_TOKEN claude "$@"
    }
  '';

  # `moshi-hook install` が生成する Claude Code hooks を宣言的に転記する。
  # settings.json は home-manager 管理の read-only symlink のため moshi-hook install は使えない。
  # 各イベントで `moshi-hook claude-hook` を呼び、承認待ちやターン完了を iPhone の Moshi に通知する。
  # 生成物の正確な形は moshi-hook install の出力に準拠（moshi-hook のバージョン更新時は要再確認）。
  _claude.extraHooks =
    let
      cmd = "${moshi-hook}/bin/moshi-hook claude-hook";
      hook = async: { inherit async; type = "command"; command = cmd; };
      entry = async: [{ hooks = [ (hook async) ]; }];
      matched = matcher: { inherit matcher; hooks = [ (hook true) ]; };
    in {
      # 承認要求だけは同期(async=false)で処理し、承認ラウンドトリップを成立させる。
      PermissionRequest = [{ hooks = [ (hook false) ]; }];
      PreToolUse = [ (matched "AskUserQuestion") (matched "ExitPlanMode") ];
      PostToolUse = [ (matched "AskUserQuestion") (matched "ExitPlanMode") ];
      SessionStart = entry true;
      SessionEnd = entry true;
      Stop = entry true;
      UserPromptSubmit = entry true;
    };
}
