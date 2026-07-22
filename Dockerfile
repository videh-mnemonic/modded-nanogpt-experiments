# syntax=docker/dockerfile:1.7

FROM nvidia/cuda:12.6.2-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG CODEX_VERSION=latest

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    WORKSPACE=/workspace \
    CODEX_HOME=/workspace/.codex

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        nginx \
        openssh-server \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install --global "@openai/codex@${CODEX_VERSION}" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh \
    && chmod 700 /root/.ssh \
    && ssh-keyscan -H github.com > /root/.ssh/known_hosts \
    && chmod 600 /root/.ssh/known_hosts

# The key is intentionally copied into the final image. Build with:
#   docker build --secret id=github_ssh_key,src=/path/to/private/key ...
RUN --mount=type=secret,id=github_ssh_key,required=true \
    install -m 600 /run/secrets/github_ssh_key /root/.ssh/id_ed25519

RUN mkdir -p /run/sshd /workspace \
    && printf '%s\n' \
        'PermitRootLogin prohibit-password' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'PubkeyAuthentication yes' \
        > /etc/ssh/sshd_config.d/99-runpod.conf \
    && rm -f /etc/ssh/ssh_host_*

COPY requirements.txt /tmp/modded-nanogpt-requirements.txt

RUN python3 -m venv /opt/venv \
    && python -m pip install --upgrade pip \
    && python -m pip install --no-cache-dir -r /tmp/modded-nanogpt-requirements.txt \
    && rm /tmp/modded-nanogpt-requirements.txt

COPY --chmod=755 bootstrap-entrypoint /usr/local/bin/bootstrap-entrypoint
COPY --chmod=755 runpod-start /usr/local/bin/runpod-start

WORKDIR /workspace

VOLUME ["/workspace"]

EXPOSE 22 80 8888

ENTRYPOINT ["/usr/local/bin/bootstrap-entrypoint"]
CMD ["/usr/local/bin/runpod-start"]
