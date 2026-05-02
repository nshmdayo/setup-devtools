# setup-devtools

Personal development tools managed by Nix and Home Manager.


### Ubuntu / Debian Container

If you need a dev user:

```bash
apt update
apt install -y sudo

useradd -m -s /bin/bash dev
usermod -aG sudo dev
passwd dev

su - dev
