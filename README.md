# Ansible PC setup

This is a collection of ansible scripts I use to setup a new computer.

## How to use

1. Make sure python3 and ansible are installed. On default ubuntu Python3 should be available, see [here](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) for Ansible installation instructions. (*TODO* Better document my favorite way to do it)

2. Clone this repo
3. Create a file for the new PC

       touch "install_$(hostname).yml"

4. Add the basics in the file

       ---
       - hosts: local
         become: false
         vars_files:
           - "./vars/config.local"

         roles:
           - role: system/base
             become: yes

5. Add the roles as needed taking inspiration from the existing files
6. Run `./install` (`-C` allows to run in dry mode)
7. ⚠ Check the logs some tasks add a message saying what to do next
