{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    git
    gh
    jq
    curl
    nixfmt-rfc-style
  ];

  shellHook = ''
    echo "setup-devtools dev shell"
  '';
}
