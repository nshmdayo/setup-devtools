{ ... }:

{
  programs.git = {
    enable = true;

    userName = "Naoto Nishihama";
    userEmail = "personal@example.com";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };

    includes = [
      {
        condition = "gitdir:~/src/personal/";
        contents = {
          user = {
            name = "Naoto Nishihama";
            email = "personal@example.com";
          };

          core = {
            sshCommand = "ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes";
          };
        };
      }

      {
        condition = "gitdir:~/src/work/";
        contents = {
          user = {
            name = "Naoto Nishihama";
            email = "work@example.co.jp";
          };

          core = {
            sshCommand = "ssh -i ~/.ssh/id_ed25519_work -o IdentitiesOnly=yes";
          };
        };
      }

      {
        condition = "gitdir:~/src/oss/";
        contents = {
          user = {
            name = "nshmdayo";
            email = "oss@example.com";
          };

          core = {
            sshCommand = "ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes";
          };
        };
      }
    ];
  };
}
