FROM ubuntu:25.04

# Install aws-cli deps and cron
RUN apt update && \
    apt install -y \
        curl \
        unzip \
        cron \
        && apt-get clean

# Install the aws cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Set up the backup files
COPY --chmod=744 ./builder/backup/backup-script.sh /backup-script.sh
COPY --chmod=644 ./builder/backup/backup-crontab /etc/cron.d/backup-crontab
RUN crontab /etc/cron.d/backup-crontab
RUN touch /var/log/cron.log

# 1. Copy the relevant env variables to a file so that they are accessible once we run cron
# 2. Start cron responsible for regularly running the backup script
# 3. Run a never ending tail -f to avoid the container shutting down
CMD printenv | grep -E 'AWS_' > /etc/environment && cron && tail -f /var/log/cron.log
