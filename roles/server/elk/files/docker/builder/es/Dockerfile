ARG STACK_VERSION
FROM docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} AS builder

ARG AWS_ACCESS_KEY
ARG AWS_SECRET_KEY

RUN echo "$AWS_ACCESS_KEY" > /tmp/access_key
RUN echo "$AWS_SECRET_KEY" > /tmp/secret_key
RUN /usr/share/elasticsearch/bin/elasticsearch-keystore add -f --stdin s3.client.default.access_key < /tmp/access_key
RUN /usr/share/elasticsearch/bin/elasticsearch-keystore add -f --stdin s3.client.default.secret_key < /tmp/secret_key

ARG STACK_VERSION
FROM docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
COPY --from=builder /usr/share/elasticsearch/config/elasticsearch.keystore /usr/share/elasticsearch/config/elasticsearch.keystore
