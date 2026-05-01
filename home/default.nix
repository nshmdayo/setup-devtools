{ ... }:

{
  imports = [
    ./packages.nix
    ./git.nix
    ./ssh.nix
    ./shell.nix
    ./ai-cli.nix
  ];

  programs.home-manager.enable = true;
}
