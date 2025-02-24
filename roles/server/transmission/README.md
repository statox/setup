# Transmission + webserver

This role installs transmission to get torrents, nginx to expose the download directory to easily share the files via HTTP and atmoz/sftp to access them viw SFTP.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the services

## Tooling

- Both transmission and Nginx are installed through docker containers
- atmoz/sftp installs an Alpine linux docker container with a `remote` user configured and a volume mount to access the directory where transmission stores its downloaded files

## Usage

- In the `.env.j2` file change the port for the web UI and make sure the `TRANSMISSION_DATA_DIR` is a proper directory

  - By default, `TRANSMISSION_DATA_DIR` is configured at `/home/transmission`
  - The directory is created with mode `755` which allows remote to acces it
  - The permissions can probably be reworked but for now it looks like this:
    ```
    ubuntu@panda:/home$ ls -l /home
    drwxr-xr-x  5 root   remote 4096 Apr 30 18:05 transmission
    ```

- It also requires 2 variables to let traefik know on which domain each container should be exposed

```yaml
- role: server/transmission
  vars:
    transmission_ui_domain: "transmission.statox.fr"
    transmission_media_domain: "media.statox.fr"
```

Nginx is configured to have `/` password protected and exposing the download directory:

- The password protection is configured in the `htpasswd` file in the nginx builder directory. (The format is documented [here](https://httpd.apache.org/docs/2.4/misc/password_encryptions.html))
- The format I have used is `username:[passwordhash]` with `[passwordhash]` generated with `openssl passwd -apr1 myPassword`

The secrets are stored in the `vars/secrets.yml.enc` ansible-vault file


- The user configured for sftp access is `remote`, its password is stored in the ansible-vault file and injected in `users.conf` which is then read by the atmoz/sftp container.
- We also provide some SSH host key files to the container so that recreating the container doesn't change the host keys and avoid giving MITM alerts to clients
