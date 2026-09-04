# quipper/claudia — LiteLLM Proxy + Entra ID SSO 経由で Claude Code を起動する社内 CLI。
# flake input にしない理由:
# quipper の private リポジトリのため SSH 認証が必要で、input にすると
# quipper へのアクセス権がないマシン（private プロファイル）での
# `nix flake update` が全 input の fetch で失敗する。
# builtins.fetchGit を rev 固定で overlay に置けば、claudia を参照する
# recruit の評価時にだけ遅延 fetch される。
# 更新するときはこの rev を最新コミット SHA に書き換える。
final: _prev: {
  claudia = final.rustPlatform.buildRustPackage rec {
    pname = "claudia";
    version = "0.1.2";
    src = builtins.fetchGit {
      url = "ssh://git@github.com/quipper/claudia";
      rev = "0b574d8e0ea02fb359a7787c3028402f6f78940d";
    };
    cargoLock.lockFile = "${src}/Cargo.lock";
  };
}
