#####################
# BUILD ENVIRONMENT #
#####################

FROM golang:alpine AS build_chia_exporter

WORKDIR /build

RUN apk add --update --no-cache --virtual build-dependencies git ca-certificates && \
    git clone --depth 1 -b 0.15.4 https://github.com/Chia-Network/chia-exporter.git && \
    cd chia-exporter && \
    go build -o chia_exporter

#####################
# FINAL ENVIRONMENT #
#####################

FROM debian:bookworm-slim

LABEL maintainer="contact@pool.energy"

RUN apt-get update && \
    apt-get upgrade -y
RUN apt-get install -y git python3-venv lsb-release sudo procps tmux net-tools vim iputils-ping netcat-traditional

WORKDIR /root/chia-exporter

COPY --from=build_chia_exporter /build/chia-exporter/chia_exporter /root/chia-exporter/chia_exporter

WORKDIR /root

COPY . /root/chia-blockchain

WORKDIR /root/chia-blockchain

RUN sh install.sh

EXPOSE 58444
EXPOSE 8444
EXPOSE 8555
EXPOSE 9256
EXPOSE 9914

COPY ./docker/entrypoint.sh /entrypoint.sh
COPY ./docker/update-config.py /root/update-config.py

ENV PATH=/root/chia-blockchain/venv/bin:$PATH

CMD ["bash", "/entrypoint.sh"]
