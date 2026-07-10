{ pkgs, ... }: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "1password-cli"
      "claude-code"
    ];

  # self-hosted runner の github-runner に node20 externals を復活させる
  # (overlays/github-runner.nix) ために、EOL でありながら必要な node20 を明示許容する。
  # actions/checkout 等の JS Action が using: node20 を要求するため避けられない。
  # バージョン文字列は nixpkgs の nodejs_20 更新時に追従が必要（あえて pin して
  # 更新のたびに insecure を再確認する運用とする）。node24 移行完了後は削除する。
  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-20.20.2"
    "nodejs-slim-20.20.2"
  ];

  # ログイン画面をユーザー一覧ではなく「名前＋パスワード」入力欄にする。
  # self-hosted runner の hidden ユーザー _ghrunner はアイコン一覧に出ないため、
  # ログイン画面から名前を打って直接ログイン（GUI セッション確保）できるようにする。
  system.defaults.loginwindow.SHOWFULLNAME = true;

  # ファストユーザスイッチを有効化する。
  # _ghrunner の GUI(Aqua) セッションへ都度切り替えて run.sh を起動する運用のため、
  # ログアウトせずにユーザーを切り替えられるようにする。
  #
  # typed な system.defaults.".GlobalPreferences" ではなく CustomSystemPreferences に
  # 絶対パスで書く理由: 前者は primaryUser のユーザー設定(~/Library/Preferences)に書かれるが、
  # FUS はシステム全体(/Library/Preferences/.GlobalPreferences)の MultipleSessionEnabled で
  # 制御されるため、システムドメインへ直接書く必要がある。
  system.defaults.CustomSystemPreferences."/Library/Preferences/.GlobalPreferences".MultipleSessionEnabled = true;
}
