{ ... }: {
  homebrew = {
    # iOS ビルド runner(_ghrunner)向けの Xcode bootstrap ツール。
    # Homebrew はマシン全体で1つのため _ghrunner の home ではなくこのホスト層に置く。
    #
    # xcodes を nixpkgs ではなく brew にする理由:
    # xcodes は Apple 認証・2FA・Keychain セッション保存・unxip を伴う一回こっきりの
    # bootstrap ツールで、ベンダ署名済みの brew リリース版の方が Keychain 識別子が安定し
    # Apple/Xcode 仕様変更にも自動追従する（core 2.0.3 で nixpkgs 1.6.2 より新しい）。
    # CI のホットパスではない（ジョブは installed Xcode の xcodebuild を使う）ため
    # nix の再現性 pin の利得は小さい。
    #
    # aria2 を入れない理由:
    # この Mac では aria2 が持ち込む OpenSSL の信頼ストアが正規の Sectigo チェーンを
    # 検証できず（openssl@3 の既定 cert.pem 不在＋system keychain 取り込みが不完全）、
    # 全 HTTPS DL が TLS で落ちる。xcodes は --no-aria2 の native downloader
    # (Secure Transport) で確実に通るため、常に失敗する aria2 は宣言しない。
    brews = [
      "xcodes"
    ];

    casks = [
      "salesforce-cli"

      # iOS の Moshi アプリから外出先も含めて到達するための WireGuard メッシュ VPN。
      # App Store 版ではなく standalone 版（cask 名は tailscale から tailscale-app に改称済み）を使う理由:
      # standalone 版は sandbox 制約が無く tailscale CLI をそのまま叩けて開発用途に適するため。
      "tailscale-app"
    ];
  };
}
