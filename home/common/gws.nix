{ pkgs, lib, ... }:
let
  # gws の --scopes は「追加」ではなく「完全置き換え」で、上流の DEFAULT_SCOPES は
  # マージされない。1 つ足すときも全件を列挙すること。
  defaultScopes = [
    "https://www.googleapis.com/auth/drive"
    "https://www.googleapis.com/auth/documents"
    "https://www.googleapis.com/auth/spreadsheets"
    "https://www.googleapis.com/auth/presentations"
    "https://www.googleapis.com/auth/forms"

    "https://www.googleapis.com/auth/calendar"
    "https://www.googleapis.com/auth/tasks"
    "https://www.googleapis.com/auth/meetings.space.created"
    "https://www.googleapis.com/auth/meetings.space.readonly"
    "https://www.googleapis.com/auth/meetings.space.settings"

    "https://www.googleapis.com/auth/gmail.modify"
    "https://www.googleapis.com/auth/gmail.readonly"
    "https://www.googleapis.com/auth/gmail.compose"
    "https://www.googleapis.com/auth/gmail.send"
    "https://www.googleapis.com/auth/gmail.insert"
    "https://www.googleapis.com/auth/gmail.metadata"
    "https://www.googleapis.com/auth/gmail.labels"
    "https://www.googleapis.com/auth/gmail.settings.basic"
    "https://www.googleapis.com/auth/gmail.settings.sharing"
    "https://www.googleapis.com/auth/gmail.addons.current.action.compose"
    "https://www.googleapis.com/auth/gmail.addons.current.message.action"
    "https://www.googleapis.com/auth/gmail.addons.current.message.metadata"
    "https://www.googleapis.com/auth/gmail.addons.current.message.readonly"

    "https://www.googleapis.com/auth/script.projects"
    "https://www.googleapis.com/auth/script.deployments"
    "https://www.googleapis.com/auth/script.processes"
    "https://www.googleapis.com/auth/script.metrics"

    # restricted 扱いのため、未検証の OAuth クライアントでは同意画面が
    # Error 403: restricted_client で落ち、同一リクエストの他 scope も巻き添えになる。
    "https://www.googleapis.com/auth/pubsub"
    "https://www.googleapis.com/auth/cloud-platform"

    "https://www.googleapis.com/auth/userinfo.email"
    "https://www.googleapis.com/auth/userinfo.profile"
  ];

  # wrapProgram を使わない理由: 引数を無条件に前置・後置するだけなので
  # 「auth login かつ scope フラグ無し」の条件分岐が書けず、
  # 素の gws サブコマンドまで --scopes で汚染してしまう。
  #
  # --scopes を渡すと上流の TTY 用インタラクティブ scope picker もスキップされる。
  gws = pkgs.writeShellApplication {
    name = "gws";
    text = ''
      REAL_GWS="${pkgs.gws}/bin/gws"
      DEFAULT_SCOPES="${lib.concatStringsSep "," defaultScopes}"

      scopes="''${GWS_SCOPES:-$DEFAULT_SCOPES}"

      if [ "''${1:-}" = "auth" ] && [ "''${2:-}" = "login" ]; then
        for arg in "$@"; do
          case "$arg" in
            --scopes | --readonly | --full)
              exec "$REAL_GWS" "$@"
              ;;
          esac
        done
        exec "$REAL_GWS" "$@" --scopes "$scopes"
      fi

      exec "$REAL_GWS" "$@"
    '';

    meta = {
      description = "gws with declarative default OAuth scopes";
      mainProgram = "gws";
    };
  };
in
{
  home.packages = [ gws ];
}
