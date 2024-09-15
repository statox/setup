# Transmission + webserver

Transmission to get torrents and nginx to expose the download directory to easily share the files.

## Usage

- In the `.env` file change the creds for the web UI and make sure the `TRANSMISSION_DATA_DIR` is a proper directory

  - On panda `TRANSMISSION_DATA_DIR` is configured at `/home/transmission` with the tranmission user already created manually (TODO add the creation in an ansible playbook)
  - We also have the `remote` user created to have the directory accessible from marmite
  - The permissions can probably be reworked but for now it looks like this:
    ```
    ubuntu@panda:/home$ ls -l /home
    drwxr-xr-x  5 root   remote 4096 Apr 30 18:05 transmission
    ```

Nginx is configured to have `/films` password protected and exposing the download directory:

- The password protection is configured in the `htpasswd` file in the nginx builder directory. (The format is documented [here](https://httpd.apache.org/docs/2.4/misc/password_encryptions.html))
- The format I have used is `username:[passwordhash]` with `[passwordhash]` generated with `openssl passwd -apr1 myPassword`
