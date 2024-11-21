# ELK stack

This role installs the ELK stack with an elasticsearch master and data single node, kibana and logstash. Also some attempts at beat system was created and need to be reworked.

## Dependencies

This role needs other roles to have run:

- `system/docker` role to get docker
- `server/traefik` to have a reverse proxy to expose the services
