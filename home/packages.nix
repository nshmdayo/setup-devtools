{ pkgs, lib, ... }:

{
  home.packages =
    with pkgs;
    [
      # Bootstrap / basic
      ca-certificates
      curl
      wget
      gnupg
      unzip
      zip

      # Development basics
      git
      gh
      neovim
      jq
      ripgrep
      fd
      fzf
      bat
      eza

      # Build tools
      gcc
      gnumake
      pkg-config

      # Current mise global tools replacement
      nodejs_24
      go
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      podman
    ];
}
