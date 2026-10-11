# gastownhall/gastown — Claude Code のエージェント群を tmux 上で統括する CLI（gt）。
#
# 上流の flake 出力（#gt）を使わない理由: nixpkgs ピンと vendorHash が HEAD の
# go.mod / go.sum に追従しておらず、Go 1.26.1（go.mod は 1.26.2 要求）・vendorHash
# mismatch・ICU 未指定の 3 点でビルドが落ちる。flake が buildGoModule を直接呼ぶため
# vendorHash を override する手段も無い。
#
# flake input にせず rev をここに固定する理由: rev を進めるたび vendorHash の貼り替えが
# 必要で、`nix flake update` による自動追従では無言で壊れる（claudia と同じ方針）。
#
# 更新するときは rev・hash・vendorHash を書き換える
# （hash は lib.fakeHash でビルドし mismatch の `got:` から取得できる）。
{ lib, buildGoModule, fetchFromGitHub, icu }:

buildGoModule rec {
  pname = "gastown";
  # 上流は release 後も version.go の Version を 1.2.1 に据え置いたまま HEAD を進めており、
  # バイナリの自己申告も 1.2.1 になる。実体は release より後なので unstable 表記で区別する。
  version = "1.2.1-unstable-2026-10-08";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gastown";
    rev = "649b832b7672bc7a2dbef26f5983aba6198b819b";
    hash = "sha256-DCa/GlDNG5z/YgSy7HrBsCEuVwvOADDlPagSdSYh7HM=";
  };

  vendorHash = "sha256-ZUEQQ0br+5UQnk/XLM7NLDCd1qA93VOho1iQ3q3RUm8=";

  # dolthub/go-icu-regex が cgo で ICU ヘッダを要求する。beads の gms_pure_go のような
  # タグで回避する道は無い（上流 .goreleaser.yml も全 OS で CGO_ENABLED=1）。
  buildInputs = [ icu ];

  # cmd/ 配下の gt-proxy-server / gt-proxy-client / gt-desktop は使わないので gt だけに絞る。
  subPackages = [ "cmd/gt" ];

  # BuiltProperly が空だと root.go が darwin で os.Exit(1) する（未署名バイナリ対策の
  # ガード。Nix では Go のリンカが ad-hoc 署名を付けるため実害は無い）。
  # module path が steveyegge なのは go.mod の module がそのままなため
  # （上流 flake が併記する gastownhall 側は存在しないシンボルを指し no-op になる）。
  ldflags = [
    "-X github.com/steveyegge/gastown/internal/cmd.Build=nix"
    "-X github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
  ];

  meta = {
    description = "Multi-agent orchestration system for Claude Code with persistent work tracking";
    homepage = "https://github.com/gastownhall/gastown";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    mainProgram = "gt";
  };
}
