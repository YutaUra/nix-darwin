# llm を nixpkgs の pkgs.llm ではなく自前で組み上げる理由:
# llm-openai-decisions は llm>=0.36 を要求し（llm.parts モジュールは 0.36 で追加された）、
# nixpkgs-unstable の llm は 0.35 で止まっているため、llm とプラグインを PyPI sdist から作る。
# いずれも pure Python なのでコンパイルは発生しない。
#
# openai を override しない理由:
# llm 0.36 は openai>3 を要求する。nixpkgs が openai 2.53.0 だった頃は 3.3.0 への
# override が必要だったが、nixpkgs が 3.14.1 へ追従したため不要になった。
# override を残すと base（nixpkgs の openai）の build-system をそのまま継承するため、
# nixpkgs 側が openai 3.14 系に合わせて build-system を hatchling のみへ減らした時点で、
# 3.3.0 が要求する hatch-fancy-pypi-readme がビルド環境から欠けて落ちる。
# 同じ理由で、将来 openai を再びピンしたくなった場合は build-system も明示すること。
#
# pkgs.llm.withPlugins を使わない理由:
# withPlugins の引数は nixpkgs 収録済みプラグイン名の固定リストで、out-of-tree の
# プラグインを渡す口がない。llm のプラグイン発見は entry point 経由なので、
# 同一 Python 環境へ同梱すれば withPlugins と同じ結果になる。
{ lib, python3Packages, fetchPypi, runCommand }:

let
  ps = python3Packages;

  llm = ps.buildPythonPackage (finalAttrs: {
    pname = "llm";
    version = "0.36";
    pyproject = true;

    src = fetchPypi {
      inherit (finalAttrs) pname version;
      hash = "sha256-5ZrTCHWpm+LuoMiAVDsev+QO6iSuVdQAjrHhLHeWRiY=";
    };

    build-system = [ ps.setuptools ];

    dependencies = with ps; [
      click
      click-default-group
      condense-json
      httpx2
      openai
      pip
      pluggy
      puremagic
      pydantic
      python-ulid
      pyyaml
      setuptools
      sqlite-utils
      typing-extensions
    ];

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
