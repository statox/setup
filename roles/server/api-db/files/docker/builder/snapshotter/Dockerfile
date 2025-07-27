FROM ubuntu:25.04

# Install aws-cli deps, cron and the mysql client
RUN apt update && \
    apt install -y \
        curl \
        unzip \
        mysql-client \
        cron \
        && apt-get clean

# Install the aws cli
# TODO Would probably be safer to keep a local copy instead of getting it from internet
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Set up the snapshot files
COPY --chmod=744 ./builder/snapshotter/snapshot-script.sh /snapshot-script.sh
COPY --chmod=644 ./builder/snapshotter/snapshot-crontab /etc/cron.d/snapshot-crontab
RUN crontab /etc/cron.d/snapshot-crontab
RUN touch /var/log/cron.log

# 1. Copy the revelant env variables to a file so that they are accesible once we run cron
# 2. Start cron responsible for regularly running the scnapshot script
# 3. Run a never ending tail -f to avoid the container shutting down
CMD printenv | grep -E 'MYSQL_|AWS_' > /etc/environment && cron && tail -f /var/log/cron.log
