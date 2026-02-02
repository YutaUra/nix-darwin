# nix-darwin configuration

macOS の設定を Nix で宣言的に管理するリポジトリ。nix-darwin + home-manager + nix-homebrew を使用。

## ディレクトリ構造（3層）

```
common/          … 全プロファイル共通のシステム設定
profiles/        … プロファイル固有のシステム設定（private, recruit）
hosts/           … マシン固有の設定（hostPlatform, import の組み立て）
home/common/     … 全プロファイル共通の home-manager 設定
home/{profile}/  … プロファイル固有の home-manager 設定
```

- `common/` はシステム設定（macOS defaults, fonts, sudo, homebrew, auto-update）
- `profiles/` は `allowUnfreePredicate` 等のプロファイル差分
- `hosts/` は `common` + `profiles/*` + ホスト固有 `homebrew.nix` を import する
- `home/common/` はパッケージ、shell, git, starship, ghostty の設定
- `home/{profile}/` はプロファイル固有パッケージや git 設定の拡張枠

## flake.nix の構造

`mkDarwin` ヘルパーが `hostname`, `username`, `profile` を受け取り darwinSystem を構築する。`configName` が specialArgs で各モジュールに渡される。

現在の darwinConfigurations:
- `private` — 個人マシン（hosts/private）
- `recruit` — 仕事マシン（hosts/recruit）

## ビルド・適用コマンド

```sh
sudo darwin-rebuild switch --flake .#private
sudo darwin-rebuild switch --flake .#recruit
darwin-rebuild build --flake .#private   # build のみ（sudo 不要）
```

`switch` には sudo が必要。`build` のみであれば不要。

## 自動更新

`common/auto-update.nix` で LaunchAgent を定義。毎日 9:00 / 23:00 に `git pull` → `darwin-rebuild switch` を実行。ログは `/tmp/nix-darwin-auto-update.log`。

## 設定を追加する際の方針

- 両プロファイル共通 → `common/` または `home/common/`
- プロファイル固有 → `profiles/{name}/` または `home/{name}/`
- マシン固有（homebrew casks 等）→ `hosts/{name}/`
- Nix module system によりリスト型（`home.packages`, `homebrew.casks` 等）は複数モジュールから定義するとマージされる

## 注意

- 新規 .nix ファイル作成後は `git add` が必要（flake は Git 追跡ファイルのみ評価）
- コミットメッセージは日本語で書く
