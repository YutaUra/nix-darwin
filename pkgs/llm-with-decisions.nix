# llm を nixpkgs の pkgs.llm ではなく自前で組み上げる理由:
# llm-openai-decisions は llm>=0.36 を要求し（llm.parts モジュールは 0.36 で追加された）、
# llm 0.36 は openai>3 を要求する。一方 nixpkgs-unstable は llm 0.31.1 / openai 2.53.0 で
# 止まっているため、llm・openai・プラグインの 3 つを PyPI sdist から作る必要がある。
# いずれも pure Python なのでコンパイルは発生しない。
#
# pkgs.llm.withPlugins を使わない理由:
# withPlugins の引数は nixpkgs 収録済みプラグイン名の固定リストで、out-of-tree の
# プラグインを渡す口がない。llm のプラグイン発見は entry point 経由なので、
# 同一 Python 環境へ同梱すれば withPlugins と同じ結果になる。
{ lib, python3Packages, fetchPypi, runCommand }:

let
  ps = python3Packages;

  # llm 0.36 の `openai>3`（PEP 440 では 3.0.0 を含まない）を満たす最小の版。
  #
  # 3.3.1 以降を選ばない理由: jiter>=0.16 を要求し、Rust 製の jiter を上書きビルドする
  # ことになる。3.3.0 は jiter>=0.10 / httpx2>=2.7 のため nixpkgs 側をそのまま使える。
  openai = ps.openai.overridePythonAttrs (old: rec {
    version = "3.3.0";

    src = fetchPypi {
      pname = "openai";
      inherit version;
      hash = "sha256-KPkEqfv/FSiOndZ7wPcCDU9XbTd4Y4OkgNsC/l2BOdM=";
    };

    # openai 3.x は httpx を httpx2 へ移し tqdm への依存をやめた（distro は 3.3.0 では
    # まだ必要）。nixpkgs の 2.53.0 向けリストは実体と合わないため置き換える。
    dependencies = with ps; [
      anyio
      distro
      httpx2
      jiter
      pydantic
      sniffio
      typing-extensions
    ];

    # pyproject は hatchling を ==1.26.3 に固定するが nixpkgs は 1.31.0 のみ。
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'hatchling==1.26.3' 'hatchling'
    '';

    # nixpkgs のテスト設定は httpx ベースのモック（respx）依存で、httpx2 へ移行した 3.x では成立しない。
    doCheck = false;

    # nixpkgs 側は fetchFromGitHub の tag を参照しているため、fetchPypi に差し替えると評価が落ちる。
    meta = old.meta // {
      changelog = "https://github.com/openai/openai-python/blob/v${version}/CHANGELOG.md";
    };
  });

  llm = ps.buildPythonPackage (finalAttrs: {
    pname = "llm";
    version = "0.36";
    pyproject = true;

    src = fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-5ZrTCHWpm+LuoMiAVDsev+QO6iSuVdQAjrHhLHeWRiY=";
    };

    build-system = [ ps.setuptools ];

    dependencies = [ openai ] ++ (with ps; [
      click
      click-default-group
      condense-json
      httpx2
      pip
      pluggy
      puremagic
      pydantic
      python-ulid
      pyyaml
      setuptools
      sqlite-utils
      typing-extensions
    ]);

    # sdist にテストが含まれないため doCheck は立てられない。
    doCheck = false;
    pythonImportsCheck = [ "llm" ];

    meta = {
      homepage = "https://github.com/simonw/llm";
      description = "Access large language models from the command-line";
      changelog = "https://github.com/simonw/llm/releases/tag/${finalAttrs.version}";
      license = lib.licenses.asl20;
      mainProgram = "llm";
    };
  });

  llm-openai-decisions = ps.buildPythonPackage (finalAttrs: {
    pname = "llm_openai_decisions";
    version = "0.1";
    pyproject = true;

    src = fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-3/tf8OCuPUUfWk4OPhEkgn2szNGMd3Z11y/GGhiic54=";
    };

    build-system = [ ps.hatchling ];

    dependencies = [ llm ] ++ (with ps; [
      httpx2
      pydantic
    ]);

    # httpx2 の下限（>=2.13.0）を緩める理由: 2.13.1 へ上げると httpcore2==2.13.1 の同時更新を
    # 伴い httpx2 依存パッケージ全体を再ビルドする。プラグインが使う API は
    # Client(timeout, follow_redirects) / AsyncClient / HTTPError だけで 2.9.1 に存在する。
    pythonRelaxDeps = [ "httpx2" ];

    # dev 依存の httpx2-pytest が nixpkgs 未収録。
    doCheck = false;
    pythonImportsCheck = [ "llm_openai_decisions" ];

    meta = {
      homepage = "https://github.com/simonw/llm-openai-decisions";
      description = "LLM plugin for the OpenAI Decisions API";
      license = lib.licenses.asl20;
    };
  });

  pythonEnv = ps.python.withPackages (_: [ llm llm-openai-decisions ]);
in
# withPackages の環境は propagatedBuildInputs 由来の無関係な実行ファイル（python, pip 等）も
# bin に並べてしまうため、nixpkgs の llm.withPlugins と同じく llm だけを張り出す。
runCommand "llm-${llm.version}-with-openai-decisions"
{
  inherit (llm) meta;
} ''
  mkdir -p $out/bin
  ln -s ${pythonEnv}/bin/llm $out/bin/llm
''
