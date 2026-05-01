{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    go
    gopls
    delve
    golangci-lint
    gotools
    just
  ];

  shellHook = ''
    echo "Go dev shell"
    go version
  '';
}
