{ pkgs, ... }:

let
  codex = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ pkgs.nodejs_24 ];
    text = ''
      exec npx -y @openai/codex "$@"
    '';
  };

  gemini =
    if builtins.hasAttr "gemini-cli" pkgs then
      pkgs."gemini-cli"
    else
      pkgs.writeShellApplication {
        name = "gemini";
        runtimeInputs = [ pkgs.nodejs_24 ];
        text = ''
          exec npx -y @google/gemini-cli "$@"
        '';
      };

  claude =
    if builtins.hasAttr "claude-code" pkgs then
      pkgs."claude-code"
    else
      pkgs.writeShellApplication {
        name = "claude";
        runtimeInputs = [ pkgs.nodejs_24 ];
        text = ''
          exec npx -y @anthropic-ai/claude-code "$@"
        '';
      };
in
{
  home.packages = [
    codex
    gemini
    claude
  ];
}
