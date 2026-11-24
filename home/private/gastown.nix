# Gas Town（gt）本体と周辺依存（beads / dolt / tmux / shell 連携）の一式。
{ pkgs, lib, ... }:
let
  # 上流 flake が HEAD に追従できずビルド不能なため自前パッケージ化している（理由は pkgs/gastown.nix）。
  gastown = pkgs.callPackage ../../pkgs/gastown.nix { };

  # `gt shell install` が書き出す shell-hook.sh を、RC ファイルに触らせずに取り出す。
  # 実機で直接実行しない理由: Install() はフック生成後に ~/.zshrc へ追記するが、
  # home-manager 管理下の ~/.zshrc は read-only symlink なので必ず失敗する。
  # HOME をサンドボックスへ向ければ追記だけが捨てられ、フック本体が得られる
  # （フックは静的な文字列で $HOME は実行時解決のため、サンドボックスのパスは焼き付かない）。
  # 中身を書き写さない理由: この形なら gastown 更新時にフックも追従する。
  gastownShellHook = pkgs.runCommand "gastown-shell-hook.sh" { } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${gastown}/bin/gt shell install > /dev/null 2>&1 || true
    cp "$HOME/.config/gastown/shell-hook.sh" "$out"
  '';
in
{
  imports = [
    # `gt up` と tmux ベースの役割が tmux 3.0+ を必須とする。普段は herdr で
    # 足りているが、gastown はセッション一覧・pane 操作を tmux に直接依存していて代替不可。
    ../common/tmux.nix
  ];

  home.packages = [ gastown ] ++ (with pkgs; [
    # gastown がエージェントの外部メモリとして使う issue tracker（bd）。
    beads

    # beads のバックエンド。README の prerequisites 表には無いが、`gt install` は
    # beads 有効時に PATH 上の dolt を実行時必須として強制する。sql-server の
    # 上げ下げは gt 自身が行うので、こちらから常駐させる必要はない。
    dolt
  ]);

  # gt はこのファイルを読むだけで書き換えないので symlink で問題ない
  # （gt が書き込む state.json や town 配下は宣言管理の対象にしない）。
  home.file.".config/gastown/shell-hook.sh".source = gastownShellHook;

  # doctor の global-state チェックは RC 側に "Gas Town Integration" か "shell-hook.sh"
  # があるかを source チェーンを辿って探すだけなので、initContent で代替できる。
  # 上流と同じマーカー行にしておくのは、gt shell remove / doctor が同じ文字列を探すため。
  programs.zsh.initContent = ''
    # --- Gas Town Integration (managed by gt) ---
    [[ -f "$HOME/.config/gastown/shell-hook.sh" ]] && source "$HOME/.config/gastown/shell-hook.sh"
    # --- End Gas Town ---
  '';

  # 有効化しないと doctor が global-state を not initialized とし、shell-hook の
  # _gastown_enabled も false を返してフックが実質無効になる。
  # home.file にしない理由: machine_id を含む可変状態で、gt disable が書き換える。
  # 未作成時だけ実行する理由: 無条件だと意図した `gt disable` が switch で戻る。
  # PATH に beads を足す理由: gt enable が bd の存在確認で警告を出すため。
  home.activation.enableGastown =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/state/gastown/state.json" ]; then
        PATH="${pkgs.beads}/bin:$PATH" ${gastown}/bin/gt enable > /dev/null 2>&1 \
          || echo "warning: gt enable に失敗しました" >&2
      fi
    '';
}
