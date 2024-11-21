# Traefik - Reverse proxy

The Traefik container is used as an entry point for all the exposed containers on the machine.

## Networking

The Traefik's docker compose creates a network "reverse-proxy" which must be used by the proxified containers so that traefik can actually reach them and route the incoming requests to the containers.

The other docker compose need to declare the network as external (since it is created by the Traefik stack)

```docker-compose
networks:
  reverse-proxy:
    external: true
```

And then add each container to the network

```docker-compose
services:
    service-name:
        ...
        networks:
          - reverse-proxy
```

## Configuration

To be exposed a container needs to have some labels defined:

```docker-compose
services:
    service-name:
        ...
        labels:
            # Enables traefik routing
            - "traefik.enable=true"
            # The DNS entry must point to the host server ip
            - "traefik.http.routers.transmission.rule=Host(`transmission.statox.fr`)"
            # Use SSL (See next section for details)
            - "traefik.http.routers.transmission.entrypoints=websecure"
            - "traefik.http.routers.transmission.tls=true"
```

## SSL

All of our containers are exposed with SSL, the terminations go like this:

1. Create a DNS record on cloudflare:

   - The record must be "proxified" (orange cloud) so that Cloudflare does the SSL termination with a valid certificate
   - The record must be an "A" record pointing to the host's IP (maybe it would work with CNAME but traefik doc has a warning about that)

2. Between Cloudflare and Traefik we also use SSL:

   - Cloudflare is configured with "strict" mode to make sure the origin has a certificate but accept self-signed ones.
   - Since no certificate is configured on Traefik it will produce a default self-signed one.
3. Then Traefik reaches the containers in plain HTTP but this is completely local so good enough for me.
