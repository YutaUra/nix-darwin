# nix-darwin configuration

macOS の設定を [nix-darwin](https://github.com/nix-darwin/nix-darwin) で宣言的に管理するリポジトリです。

## 前提

- macOS (Apple Silicon)
- [Determinate Nix](https://determinate.systems/nix-installer/) がインストール済み

## セットアップ

```sh
git clone git@github.com:YutaUra/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
sudo darwin-rebuild switch --flake .#private   # 個人マシンの場合
sudo darwin-rebuild switch --flake .#recruit   # 仕事マシンの場合
```

## プロファイル

| プロファイル | 用途 | コマンド |
|---|---|---|
| `private` | 個人マシン | `sudo darwin-rebuild switch --flake .#private` |
| `recruit` | 仕事マシン | `sudo darwin-rebuild switch --flake .#recruit` |

## ディレクトリ構造

```
flake.nix             # エントリポイント
common/               # 全プロファイル共通のシステム設定
  default.nix         #   macOS defaults, fonts, sudo 等
  homebrew.nix        #   共通 Homebrew casks
  auto-update.nix     #   自動更新 LaunchAgent
profiles/
  private/            # private 固有のシステム設定
  recruit/            # recruit 固有のシステム設定
hosts/
  private/            # private マシン固有（import の組み立て、Homebrew 拡張枠）
  recruit/            # recruit マシン固有
home/
  common/             # 全プロファイル共通の home-manager 設定
    default.nix       #   パッケージ一覧
    shell.nix         #   zsh 設定
    starship.nix      #   Starship プロンプト
    git.nix           #   Git 設定
    ghostty.nix       #   Ghostty ターミナル設定
  private/            # private 固有の home-manager 設定（拡張枠）
  recruit/            # recruit 固有の home-manager 設定（Git 追加設定等）
```

## 自動更新

毎日 9:00 と 23:00 に LaunchAgent が `git pull` → `darwin-rebuild switch` を自動実行します。

- ログ: `/tmp/nix-darwin-auto-update.log`
- PC がスリープ中だった場合、起動時にキャッチアップ実行されます

## 含まれるツール

### Nix パッケージ
ripgrep, awscli2, ffmpeg, ncdu, claude-code, gh, colima, docker, nodejs_22, 1password-cli, vim

### Homebrew Casks
1Password, DisplayLink, Ghostty, Google Chrome, Raycast, Rectangle, Slack, Visual Studio Code

## カスタマイズ

- 共通設定を変更 → `common/` または `home/common/` を編集
- プロファイル固有の設定を追加 → `profiles/{name}/` または `home/{name}/` を編集
- マシン固有の Homebrew casks を追加 → `hosts/{name}/homebrew.nix` を編集
