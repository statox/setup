# Resources

- Docker installation instructions: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-configuration-methods
- Inspiration for the docker file: https://www.elastic.co/blog/getting-started-with-the-elastic-stack-and-docker-compose

# Notes

- This creates a single node cluster with es01 being both master and data node
- Kibana runs in its own container
- Logstash runs in its own container too

For ELK:
- Changed setting because it was producing an error and I don't need the ML
    - `xpack.ml.enabled=false`
- Had to manually apply the `sysctl -w vm.max_map_count=262144` on the host as described in the instructions because of an error message preventing the nodes from starting


Data stream

https://www.elastic.co/guide/en/elasticsearch/reference/current/set-up-a-data-stream.html#create-data-stream

- Didn't follow the page exactly, need to check that the policy is properly used (because created after the data stream)


# TODO

- Securly create separate user to write to indices
- Setup logstash
- Setup file beats as suggested in the linked blog post
- Find a way to programmatically setup the users, data stream and kibana configuration to avoid doing that manually if I need to recreate the cluster
