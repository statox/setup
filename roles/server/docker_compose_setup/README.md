# docker_compose_setup

Install a docker-compose based application.

Call the role with

```
- name: install tranmission docker app
  import_tasks: ../../docker_compose_setup/main.yml
  vars:
    app_name: transmission
    local_docker_path: "{{role_path}}/files/docker/"
```

In `files/docker/` include:

- A `docker-compose.yml` file
- Any plain files to copy (e.g. `pipeline.conf`
- Template files ending in `.j2` the role will copy them and inject the values.
- A `.env.j2` template file with variables to be used in `docker-compose.yml`
