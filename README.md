# Ansible PC setup

This is a collection of ansible scripts I use to setup a new computer.

## How to use

1. `sudo apt install git`
1. Clone this repo
1. Run `sudo ./bootstrap` to install dependencies
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
