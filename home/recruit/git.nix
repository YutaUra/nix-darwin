{ ... }: {
  # 仕事用 Git 追加設定
  # includeIf 等で仕事用リポジトリのメール設定を切り替える場合はここに追加
  programs.git.settings = {
    # 大規模リポジトリでの git status 高速化
    core.untrackedcache = true;
    core.fsmonitor = true;
  };
}
