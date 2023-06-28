# Ansible PC setup

This is a collection of ansible scripts I use to setup a new computer.

## How to use

1. `sudo apt install git`
1. Clone this repo
1. Run `sudo ./bootstrap` to install dependencies
1. If needed update the `inventory` file
1. Update the `vars/config.local` file
1. Create a file for the new PC

       touch "install_$(hostname).yml"

1. Add the basics in the file

       ---
       - hosts: local
         become: false
         vars_files:
           - "./vars/config.local"

         roles:
           - role: system/base
             become: yes

1. Add the roles as needed taking inspiration from the existing files
1. Run `./install` (`-C` allows to run in dry mode)
1. ⚠ Check the logs some tasks add a message saying what to do next


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
- nvm, node and npm install missing
- Ubuntu 22.04 Jammy is hardcoded in several installations
- MysqlWorkbench installation seems to work fine the first time but fails when run again
