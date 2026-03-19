FROM fedora:latest

RUN dnf install -y \
    bash \
    tmux \
    git \
    hostname \
    && dnf clean all

COPY . /n2

WORKDIR /n2
