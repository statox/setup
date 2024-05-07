#!/usr/bin/env bash

LOGSTASH_ENDPOINT='http://raccoon.statox.fr:8888'
DOMAIN_ENDPOINT='https://raccoon.statox.fr:9200'
ELASTIC_USER='elastic'
ELASTIC_PASSWORD='CHANGEME'

# curl -k -H 'Content-Type: application/json' --user "$ELASTIC_USER:$ELASTIC_PASSWORD" -XGET "$DOMAIN_ENDPOINT/_cat/health"
# curl -k -H 'Content-Type: application/json' --user "$ELASTIC_USER:$ELASTIC_PASSWORD" -XPOST "$DOMAIN_ENDPOINT/test/_doc" --data '{"foo": 1}'

curl -k -H 'Content-Type: application/json' -XPOST "$LOGSTASH_ENDPOINT/test/_doc" --data '{"foo": 3}'
