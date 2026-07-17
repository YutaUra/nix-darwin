{ pkgs, lib, herdr-plugin-hunk, ... }:
let
  # プラグイン実体は nix store のパスとして link する。
  # store パスにする理由: 登録される実体が現在の home generation の内容に固定され、
  # リポジトリの配置場所（recruit と Linux コンテナで異なる）に依存しない同一の
  # nix 式で扱えるため。
  worktreeIncludePlugin = ./herdr-plugins/worktree-include;

  # hunk プラグインは flake input（flake=false のソースツリー）として取り込む。
  # in-repo の worktree-include と違いリモート由来なので、実体は flake.lock で
  # バージョン固定された store パスになる。
  hunkPlugin = herdr-plugin-hunk;
in
{
  # config.toml は herdr が通常書き込まないユーザー所有ファイルなので、plugins.json と違い
  # nix store への symlink として直接配置してよい（plugins.json は herdr 管理のため link 方式）。
  home.file.".config/herdr/config.toml".source = ./herdr-config.toml;

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

  # hunk プラグインも同じ方式（socket ゲート付き best-effort な link）で登録する。
  # link は plugin id 単位で冪等に置換されるため、毎回の switch で実行して安全。
  # 実行には python3（macOS 標準）と hunk（bun 経由: bunx hunkdiff）が PATH に必要。
  home.activation.linkHerdrHunk =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -S "$HOME/.config/herdr/herdr.sock" ]; then
        ${pkgs.herdr}/bin/herdr plugin link "${hunkPlugin}" > /dev/null 2>&1 \
          || echo "warning: herdr plugin link (hunk) に失敗しました（herdr server 未起動の可能性）" >&2
      fi
    '';
}
