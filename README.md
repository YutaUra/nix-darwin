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

### 初回（新しい Mac）

新しい Mac では SSH 鍵がまだ無いため、SSH では clone できません。
`HTTPS で clone → nix-darwin をブートストラップ → gh で SSH 鍵を登録 → remote を SSH に切替` の順で進めます。

#### 1. HTTPS でリポジトリを clone

```sh
git clone https://github.com/YutaUra/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
```

#### 2. nix-darwin をブートストラップ

`darwin-rebuild` はまだ存在しないため `nix run` で実行します。`gh` を含む各種ツールはこの段階で入ります。

```sh
sudo nix run nix-darwin -- switch --flake '.#private'   # 個人マシンの場合
sudo nix run nix-darwin -- switch --flake '.#recruit'   # 仕事マシンの場合
```

> **Note:** 既存の `/etc/nix/nix.conf` や `/etc/shells` があると競合エラーになる場合があります。その場合はバックアップして削除するか、エラーメッセージの指示に従ってください。

#### 3. gh で GitHub に SSH 鍵を登録

`gh auth login` の対話プロンプトを `--skip-ssh-key` でスキップし、SSH 鍵は `ssh-keygen` で生成、登録は `gh ssh-key add` に分離します。途中の対話はブラウザでのワンタイムコード入力のみです。

```sh
exec zsh        # gh が PATH に通った新しい shell に切り替え

# 1. SSH 鍵を生成（パスフレーズは Enter 連打で空にも、任意の値を設定することもできる）
ssh-keygen -t ed25519 -C "yuuta3594@gmail.com" -f ~/.ssh/id_ed25519

# 2. GitHub に web ブラウザで認証（gh の SSH 鍵プロンプトはスキップ）
gh auth login -h github.com -p ssh -w --skip-ssh-key

# 3. 生成した公開鍵を GitHub に登録
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
```

> **Tip:** `-N ""` を `ssh-keygen` に渡すとパスフレーズプロンプトもスキップできます（空パスフレーズになるため security trade-off に注意）。パスフレーズを使う場合は macOS Keychain に登録すると毎回の入力を省けます: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`

#### 4. リポジトリの remote を SSH に切り替え

以降の `git push` / `git pull` を SSH 経由にします。

```sh
git remote set-url origin git@github.com:YutaUra/nix-darwin.git
```

### 2回目以降

nix-darwin インストール後は `darwin-rebuild` コマンドが使えます。

```sh
sudo darwin-rebuild switch --flake '.#private'   # 個人マシンの場合
sudo darwin-rebuild switch --flake '.#recruit'   # 仕事マシンの場合
```

### Linux コンテナ（qall-k8s）

#### 自動セットアップ（推奨）

K8s 開発コンテナでは `/quipper/dotfiles/install` スクリプトがコンテナ起動時に自動実行され、Nix と home-manager がセットアップされます。

初回のみ、`scripts/install` を `/quipper/dotfiles/install` にコピーしてください：

```sh
mkdir -p /quipper/dotfiles
cp scripts/install /quipper/dotfiles/install
```

スクリプトは以下を行います：
1. curl のインストール（未インストールの場合）
2. Determinate Nix のインストール（systemd なしのコンテナ環境向け `--init none` オプション付き）
3. Nix daemon の起動
4. `~/.config/home-manager` への設定リポジトリの clone/pull
5. home-manager の適用

#### 手動セットアップ

自動セットアップを使わない場合：

```sh
# 1. Nix のインストール（systemd がないコンテナ環境向け）
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none

# 2. Nix daemon を起動（--init none の場合は自動起動しないため）
sudo /nix/var/nix/profiles/default/bin/nix-daemon &

# 3. daemon が応答するまで待機
until nix store ping > /dev/null 2>&1; do sleep 1; done

# 5. 環境変数を読み込む
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 6. 設定リポジトリを clone
git clone https://github.com/YutaUra/nix-darwin.git ~/.config/home-manager

# 7. home-manager を適用
nix run home-manager -- switch --flake ~/.config/home-manager#qall-k8s -b backup
```

#### 2回目以降

```sh
cd ~/.config/home-manager
git pull
home-manager switch --flake .#qall-k8s
```

## プロファイル

### macOS（darwinConfigurations）

| プロファイル | 用途 | コマンド |
|---|---|---|
| `private` | 個人マシン | `sudo darwin-rebuild switch --flake '.#private'` |
| `recruit` | 仕事マシン | `sudo darwin-rebuild switch --flake '.#recruit'` |

### Linux（homeConfigurations）

| プロファイル | 用途 | アーキテクチャ | コマンド |
|---|---|---|---|
| `qall-k8s` | K8s 開発コンテナ | aarch64-linux | `home-manager switch --flake '.#qall-k8s'` |

## ディレクトリ構造

```
flake.nix             # エントリポイント
scripts/
  install             # K8s コンテナ用セットアップスクリプト（/quipper/dotfiles/install にコピーして使用）
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
  qall-k8s/           # K8s 開発コンテナ用（aarch64-linux）
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
