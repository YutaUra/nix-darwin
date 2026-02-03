{ pkgs, ... }: {
  imports = [
    ./git.nix
  ];

  home.packages = with pkgs; [
    # Kubernetes
    kubectl
    stern
    kustomize
  ];
}
