# Ansible PC setup

This is a collection of ansible scripts I use to setup my workstation as well as some of my servers. It is useful only to me, don't expect the cleanest code.

## How to use this repo

1. Run `sudo ./bootstrap` to install dependencies
   - This installs [uv](https://docs.astral.sh/uv/) which is used to install and run ansible
1. If needed update the `inventory` file
1. Update the `vars/config.local` file
1. Create a file for the new PC

```bash
touch "install_$(hostname).yml"
```

1. Add the basics in the file

```yml
---
- hosts: local
 become: false
 vars_files:
   - "./vars/config.local"

 roles:
   - role: system/base
     become: yes
```

1. Add the roles as needed taking inspiration from the existing files
1. Run `./run install_[host].yml` (`-C` allows to run in dry mode)
   - This uses `uv` to invoke the `ansible-playbook` installed in the local environment
1. ⚠ Check the logs some tasks add a message saying what to do next

## Playbooks using secrets

The secrets are stored in [`/vars/secrets.yml.enc`](vars/secrets.yml.enc) which is managed with the built-in [`ansible-vault`](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html#encrypting-files-with-ansible-vault).

**The key for the file is in my Dashlane secure note "statox-setup secret file"**

The script [`/vars/get-vault-password.sh`](/vars/get-vault-password.sh) is a helper which calls [dcli](https://github.com/Dashlane/dashlane-cli) to get the password from the secure note. This script can be used with the `--vault-password-file` parameter of `ansible-vault` to automatically unlock the password if dcli is available.

```bash
# The vault was not created with a --vault-id param
uv run -- ansible-vault view --vault-password-file vars/get-vault-password.sh vars/secrets.yml.enc
```

To run a playbook using this the secrets:

- `./run install_raccoon.yml -e @vars/secrets.yml.enc --vault-password-file vars/get-vault-password.sh`
- The variables in `vars/secrets.yml.enc` can be used as regular Ansible variables `{{ transmission_user }}`
- Note that for the docker-apps module we can create `*.j2` template files using the `{{ encrypted_variable }}` syntax, the module will copy the template and inject the variable

## TODO

- Handle desktop environement restart on first install
- Add new Github SSH key to known keys (prevent cloning dotfiles repo)
- Rework Firefox chrome (fails on first install because profile is not found)
- In dotfiles:
  - There seems to be a bug where the directories in `.config` are not created so the files can't be copied
  - Check how to execute the install from ansible
- warp and miro clients install are broken
- configure npm repository: Needs to create .npmrc file
- work/gitlab seems broken
- Check how to automatically setup Firefox sync
- zsh is not automatically enabled
- Ubuntu 22.04 Jammy is hardcoded in several installations
- MysqlWorkbench installation seems to work fine the first time but fails when run again
- pnpm install `npm install -g pnpm@6`
