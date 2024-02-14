#!/bin/bash
dnf -y update
aws configure set default.region ${aws_region}
## Install Docker Engine
dnf install -y docker
systemctl enable --now docker
## Install Docker Compose
CLI_DIR=/usr/local/lib/docker/cli-plugins
LATEST_RELEASE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep -i $(uname -s)-$(uname -m) | grep -v sha256 | cut -d : -f 2,3 | tr -d \")
mkdir -p "$CLI_DIR"
curl -sL "$LATEST_RELEASE" -o "$CLI_DIR/docker-compose"
chmod +x "$CLI_DIR/docker-compose"
ln -s "$CLI_DIR/docker-compose" /usr/bin/docker-compose
## Run Docker Container
docker container run --name nginx --restart=always -d -p 80:80 nginx
