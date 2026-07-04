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
