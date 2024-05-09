#!/usr/bin/env bash

# DOMAIN_ENDPOINT='https://raccoon.statox.fr:9200'
# ELASTIC_USER='elastic'
# ELASTIC_PASSWORD='CHANGEME'
# curl -k -H 'Content-Type: application/json' --user "$ELASTIC_USER:$ELASTIC_PASSWORD" -XGET "$DOMAIN_ENDPOINT/_cat/health"
# curl -k -H 'Content-Type: application/json' --user "$ELASTIC_USER:$ELASTIC_PASSWORD" -XPOST "$DOMAIN_ENDPOINT/test/_doc" --data '{"foo": 1}'

LOGSTASH_ENDPOINT='http://raccoon.statox.fr:8888'
LOGGER_USER='logger'
LOGGER_PASSWORD='CHANGEME'

curl -v -k -H 'Content-Type: application/json' --user "$LOGGER_USER:$LOGGER_PASSWORD" -XPOST "$LOGSTASH_ENDPOINT/api.statox.fr/_doc" --data '{"content": "This is a test content"}'
