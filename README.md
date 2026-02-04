# nix-darwin configuration

macOS の設定を [nix-darwin](https://github.com/nix-darwin/nix-darwin) で宣言的に管理するリポジトリです。
Linux 開発コンテナ向けには [home-manager](https://github.com/nix-community/home-manager) 単体での設定も提供しています。

## 前提

### macOS
- macOS (Apple Silicon)
- [Determinate Nix](https://determinate.systems/nix-installer/) がインストール済み

### Linux コンテナ
- Nix がインストール済み

## セットアップ

```sh
git clone git@github.com:YutaUra/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
```

### 初回（nix-darwin 未インストールの場合）

初回は `darwin-rebuild` コマンドがまだ存在しないため、`nix run` でブートストラップします。

```sh
sudo nix run nix-darwin -- switch --flake '.#private'   # 個人マシンの場合
sudo nix run nix-darwin -- switch --flake '.#recruit'   # 仕事マシンの場合
```

> **Note:** 既存の `/etc/nix/nix.conf` や `/etc/shells` があると競合エラーになる場合があります。その場合はバックアップして削除するか、エラーメッセージの指示に従ってください。

### 2回目以降

nix-darwin インストール後は `darwin-rebuild` コマンドが使えます。

```sh
sudo darwin-rebuild switch --flake '.#private'   # 個人マシンの場合
sudo darwin-rebuild switch --flake '.#recruit'   # 仕事マシンの場合
```

### Linux コンテナ

#### 1. Nix のインストール

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

インストール後、シェルを再起動するか `source` でパスを通します：

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

#### 2. home-manager の適用

```sh
# GitHub から直接適用
nix run home-manager -- switch --flake github:YutaUra/nix-darwin#qall-k8s
```

#### 2回目以降

```sh
# home-manager コマンドが使える
home-manager switch --flake github:YutaUra/nix-darwin#qall-k8s
```

## プロファイル

### macOS（darwinConfigurations）

| プロファイル | 用途 | コマンド |
|---|---|---|
| `private` | 個人マシン | `sudo darwin-rebuild switch --flake '.#private'` |
| `recruit` | 仕事マシン | `sudo darwin-rebuild switch --flake '.#recruit'` |

### Linux（homeConfigurations）

| プロファイル | 用途 | コマンド |
|---|---|---|
| `qall-k8s` | K8s 開発コンテナ | `home-manager switch --flake '.#qall-k8s'` |

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
    default.nix       #   パッケージ一覧（macOS 用）
    shell-base.nix    #   zsh 共通設定（macOS/Linux 共用）
    shell.nix         #   zsh macOS 固有設定（colima 自動起動）
    starship.nix      #   Starship プロンプト
    git.nix           #   Git 設定
    ghostty.nix       #   Ghostty ターミナル設定
    claude-code.nix   #   Claude Code 設定
  private/            # private 固有の home-manager 設定（拡張枠）
  recruit/            # recruit 固有の home-manager 設定（Git 追加設定等）
  qall-k8s/           # K8s 開発コンテナ用の home-manager 設定
```

## 自動更新（現在無効）

~~毎日 9:00 と 23:00 に LaunchAgent が `git pull` → `darwin-rebuild switch` を自動実行します。~~

有効化するには `common/default.nix` で `./auto-update.nix` の import をコメント解除してください。

## 含まれるツール

### Nix パッケージ
ripgrep, awscli2, ffmpeg, ncdu, claude-code, gh, colima, docker, nodejs_22, 1password-cli, vim

### Homebrew Casks
1Password, DisplayLink, Ghostty, Google Chrome, Raycast, Rectangle, Slack, Visual Studio Code

## カスタマイズ

- macOS 共通設定を変更 → `common/` または `home/common/` を編集
- プロファイル固有の設定を追加 → `profiles/{name}/` または `home/{name}/` を編集
- マシン固有の Homebrew casks を追加 → `hosts/{name}/homebrew.nix` を編集
- Linux コンテナの設定を変更 → `home/qall-k8s/` を編集
