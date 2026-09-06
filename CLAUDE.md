# nix-darwin configuration

macOS の設定を Nix で宣言的に管理するリポジトリ。nix-darwin + home-manager + nix-homebrew を使用。
Linux 開発コンテナ向けには home-manager 単体での設定も提供。

## ディレクトリ構造（3層）

```
common/          … 全プロファイル共通のシステム設定（macOS）
profiles/        … プロファイル固有のシステム設定（private, recruit）
hosts/           … マシン固有の設定（hostPlatform, import の組み立て）
home/common/     … 全プロファイル共通の home-manager 設定
home/{profile}/  … プロファイル固有の home-manager 設定（private, recruit, qall-k8s）
overlays/        … nixpkgs パッケージの一時的な override（nixpkgs が追いついたら削除）
```

- `common/` はシステム設定（macOS defaults, fonts, sudo, homebrew, auto-update）
- `profiles/` は `allowUnfreePredicate` 等のプロファイル差分
- `hosts/` は `common` + `profiles/*` + ホスト固有 `homebrew.nix` を import する
- `home/common/` はパッケージ、shell, git, starship, ghostty, claude-code の設定
  - `shell-base.nix` は macOS/Linux 共通のシェル設定、`shell.nix` は macOS 固有（colima 自動起動）
- `home/{profile}/` はプロファイル固有パッケージや git 設定の拡張枠
- `scripts/install` は K8s コンテナ用セットアップスクリプト（`/quipper/dotfiles/install` にコピーして使用）

## flake.nix の構造

`mkDarwin` ヘルパーが `hostname`, `username`, `profile` を受け取り darwinSystem を構築する。`configName` が specialArgs で各モジュールに渡される。

現在の darwinConfigurations（macOS 用）:
- `private` — 個人マシン（hosts/private）
- `recruit` — 仕事マシン（hosts/recruit）

現在の homeConfigurations（Linux 用）:
- `qall-k8s` — K8s 開発コンテナ（home/qall-k8s、aarch64-linux）

## ビルド・適用コマンド

### macOS（darwin-rebuild）

```sh
sudo darwin-rebuild switch --flake '.#private'
sudo darwin-rebuild switch --flake '.#recruit'
darwin-rebuild build --flake '.#private'   # build のみ（sudo 不要）
```

`switch` には sudo が必要。`build` のみであれば不要。

ただし `build` は CPU コストが高い。変更の検証目的では下記「変更後の検証方針」を参照。

### Linux コンテナ（home-manager）

K8s 開発コンテナでは `/quipper/dotfiles/install` が自動実行され、Nix + home-manager がセットアップされる。

手動で適用する場合：
```sh
cd ~/.config/home-manager
git pull
home-manager switch --flake .#qall-k8s
```

## 変更後の検証方針

**Claude は原則としてビルド（`darwin-rebuild build` / `nix build`）を実行しない。**

このリポジトリは Rust 製ツール（claudia, logq, gati, zyouz, herdr, moshi-hook）を
ソースからビルドするため、build はキャッシュミス時に CPU を数分〜数十分占有し、
作業中のマシンの体感速度を大きく損なう。

代わりにコストの低い順で検証する。

| レベル | コマンド | 検出できるもの | コスト |
|---|---|---|---|
| L0 構文 | `nix-instantiate --parse <変更した>.nix` | 構文エラー | 一瞬 |
| L1 評価 | `nix eval --raw '.#darwinConfigurations.<profile>.config.system.build.toplevel.drvPath'` | option 名タイポ、型不一致、未定義 attribute、import 漏れ、`git add` 忘れ | コンパイルなし |
| L2 ビルド | `darwin-rebuild build --flake '.#<profile>'` | 実際のビルド失敗のみ | 高 CPU |

- 既定は **L0 → L1 まで**。Nix は評価と実現が分離しており、設定の誤りは L1 で落ちる
- **L2 はユーザーが明示的に「ビルドして」と言った場合のみ**実行する。自発的に走らせない
- home-manager 側は `nix eval --raw '.#homeConfigurations.qall-k8s.activationPackage.drvPath'`
- 新規パッケージ追加・overlay の rev 変更など評価では検出できない変更をした場合は、
  「L1 は通ったが実ビルドは未検証」と明示して報告し、ビルドするかの判断をユーザーに委ねる
- L2 を回すときは `--max-jobs 2 --cores 4` 等で CPU を絞る
- ユーザーレベルの TDD ガイドライン「変更後は必ず全テストを実行する」は、
  このリポジトリでは「L1 評価を通す」と読み替える

## 自動更新（現在無効）

`common/auto-update.nix` で LaunchAgent を定義。有効化するには `common/default.nix` で import をコメント解除する。

## 設定を追加する際の方針

- 両プロファイル共通 → `common/` または `home/common/`
- プロファイル固有 → `profiles/{name}/` または `home/{name}/`
- マシン固有（homebrew casks 等）→ `hosts/{name}/`
- Nix module system によりリスト型（`home.packages`, `homebrew.casks` 等）は複数モジュールから定義するとマージされる

## Git ワークフロー

- PR は不要。main ブランチに直接 commit & push する
- コミットメッセージは日本語で書く

## 注意

- 新規 .nix ファイル作成後は `git add` が必要（flake は Git 追跡ファイルのみ評価）
