FROM ngrok/ngrok:3.21.0-alpine

USER root

# Install dependecies
# RUN apk update
RUN apk add --no-cache jq curl bash wget git shadow coreutils

# Create a non-root user with /bin/bash as its shell
RUN adduser -D -s /bin/bash app

# Permission
RUN mkdir /app
RUN chown -R app /app

# Copy scripts
COPY ncfs.sh /app/ncfs.sh
COPY runner.sh /app/runner.sh

# Set permissions (do this as root)
RUN chmod 755 /app/runner.sh
RUN chmod 755 /app/ncfs.sh
RUN chown app:app /app/runner.sh
RUN chown app:app /app/ncfs.sh

# Change user
USER app
WORKDIR /app

EXPOSE 4040
ENTRYPOINT [ "/app/runner.sh" ]
