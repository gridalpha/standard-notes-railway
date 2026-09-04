# The SNS topics and SQS queues that carry domain events between the Standard
# Notes servers and their workers. Upstream's compose bind-mounts the bootstrap
# script into the ready hook; Railway has no bind mounts, so it is baked in.
#
# The tag matches the one standardnotes/server's own docker-compose.example.yml
# pins: LocalStack 4.x changed SQS endpoint-strategy defaults, and the app is
# configured with literal path-style queue URLs.
FROM localstack/localstack:3.0

COPY localstack/bootstrap.sh /etc/localstack/init/ready.d/bootstrap.sh

RUN chmod +x /etc/localstack/init/ready.d/bootstrap.sh \
 && bash -n /etc/localstack/init/ready.d/bootstrap.sh
