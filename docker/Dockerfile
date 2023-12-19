FROM ngrok/ngrok:alpine

USER root
# Install dependecies
# RUN apk update
RUN apk add --no-cache jq curl bash git shadow coreutils

# Create USER
RUN adduser --shell $(which bash) --disabled-password app

# Permission
RUN mkdir /app
RUN chown -R app /app

# Change user
USER app
WORKDIR /app

# Setup
RUN git clone https://github.com/barbarbar338/ncfs.git /app/ncfs
RUN mv /app/ncfs/ncfs.sh /app
RUN chmod 755 /app/ncfs.sh

EXPOSE 4040
ENTRYPOINT [ "/app/ncfs.sh" ]
