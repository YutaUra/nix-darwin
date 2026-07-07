{ pkgs, lib, ... }:
let
  # プラグイン実体は nix store のパスとして link する。
  # store パスにする理由: 登録される実体が現在の home generation の内容に固定され、
  # リポジトリの配置場所（recruit と Linux コンテナで異なる）に依存しない同一の
  # nix 式で扱えるため。
  worktreeIncludePlugin = ./herdr-plugins/worktree-include;
in
{
  # herdr の worktree-include plugin を宣言的に登録する。
  #
  # herdr はプラグインを config.toml では宣言できず、~/.config/herdr/plugins.json へ
  # `herdr plugin link` で登録する方式（レジストリは herdr が管理）。plugins.json を
  # home-manager で直接書くと herdr 側の書き込みと競合するため、activation から
  # `herdr plugin link` を呼ぶ。同一 plugin id は再 link で置換されるので冪等で、
  # 毎回の switch で実行しても安全。
  #
  # herdr server が起動していないと socket 越しの登録ができないため、socket の存在を
  # ゲートにした best-effort とする。失敗しても activation 全体は止めない
  # （次に server 起動中の switch で登録される）。
  home.activation.linkHerdrWorktreeInclude =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -S "$HOME/.config/herdr/herdr.sock" ]; then
        ${pkgs.herdr}/bin/herdr plugin link "${worktreeIncludePlugin}" > /dev/null 2>&1 \
          || echo "warning: herdr plugin link に失敗しました（herdr server 未起動の可能性）" >&2
      fi
    '';
}
