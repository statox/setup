# Transmission + webserver

This role installs transmission to get torrents and nginx to expose the download directory to easily share the files.

## Dependencies

- To run this role we need to have run the `system/docker` role to get docker

## Tooling

- Both transmission and Nginx are installed through docker containers
  - We use our custom role `user/docker-apps` to install and run these containers
- SSH: The role create a user `remote` to allow sshing to the directory where transmission stores its downloaded files
  - We also add a configuration file for sshd to make sure the authentication by password is allowed for `remote`

## Usage

- In the `.env` file change the creds for the web UI and make sure the `TRANSMISSION_DATA_DIR` is a proper directory

  - On ours `TRANSMISSION_DATA_DIR` is configured at `/home/transmission`
  - The directory is created with mode `755` which allows remote to acces it
  - The permissions can probably be reworked but for now it looks like this:
    ```
    ubuntu@panda:/home$ ls -l /home
    drwxr-xr-x  5 root   remote 4096 Apr 30 18:05 transmission
    ```

Nginx is configured to have `/films` password protected and exposing the download directory:

- The password protection is configured in the `htpasswd` file in the nginx builder directory. (The format is documented [here](https://httpd.apache.org/docs/2.4/misc/password_encryptions.html))
- The format I have used is `username:[passwordhash]` with `[passwordhash]` generated with `openssl passwd -apr1 myPassword`

- To ssh with remote we setup a password hash when creating the user, the hash was generated with mkpasswd --method=sha-512
  - TODO improve that to have the password in a vault file in the repo and dynamically create the hash
