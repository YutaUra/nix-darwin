# nixpkgs の github-runner はデフォルトで node24 externals しか同梱しない
# (nodeRuntimes のデフォルトが [ "node24" ]。node20 は EOL/insecure のため上流が省いている)。
# しかし actions/checkout・actions/cache など多くの JS Action は action.yml の
# runs.using: node20 で node20 を要求し、externals/node20/bin/node が無いと即死する。
# self-hosted runner(_ghrunner)でこれらを通すため node20 externals を復活させる。
#
# 公式 tarball への差し替えではなく override を選ぶ理由:
# nixpkgs 版は self-update 無効化パッチ + RUNNER_ROOT による状態分離を持つ。
# 公式 tarball は self-update が生きており read-only な nix store 上では自己更新に失敗して
# job が落ちるため、宣言的管理と両立しない。
#
# node20 が EOL で insecure マークのため、これを使う側(private プロファイル)で
# permittedInsecurePackages による明示許容が別途必要。
# nixpkgs が node20 を再同梱するか Action 群が node24 へ移行したら、この overlay は削除する。
final: prev: {
  github-runner = prev.github-runner.override {
    nodeRuntimes = [ "node20" "node24" ];
  };
}
