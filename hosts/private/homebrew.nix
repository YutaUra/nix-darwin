{ ... }: {
  homebrew = {
    casks = [
      "salesforce-cli"

      # iOS の Moshi アプリから外出先も含めて到達するための WireGuard メッシュ VPN。
      # App Store 版ではなく standalone 版（cask 名は tailscale から tailscale-app に改称済み）を使う理由:
      # standalone 版は sandbox 制約が無く tailscale CLI をそのまま叩けて開発用途に適するため。
      "tailscale-app"
    ];
  };
}
