FROM ngrok/ngrok:alpine

USER root
# Install dependecies
# RUN apk update
RUN apk add --no-cache jq curl bash wget git shadow coreutils

# Create USER
RUN adduser --shell $(which bash) --disabled-password app

# Permission
RUN mkdir /app
RUN chown -R app /app

# Change user
USER app
WORKDIR /app

# Setup
RUN wget https://raw.githubusercontent.com/barbarbar338/ncfs/main/docker/runner.sh -O /app/runner.sh
RUN chmod 755 /app/runner.sh

EXPOSE 4040
ENTRYPOINT [ "/app/runner.sh" ]

