# syntax=docker/dockerfile:1.7

FROM nvidia/cuda:12.6.2-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG CODEX_VERSION=latest
ARG TARGETARCH

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    WORKSPACE=/workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        openssh-client \
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

RUN git clone https://github.com/videh-mnemonic/modded-nanogpt-fork.git /workspace/modded-nanogpt-fork \
    && git clone https://github.com/videh-mnemonic/modded-nanogpt-checkpoints.git /workspace/modded-nanogpt-checkpoints \
    && git -C /workspace/modded-nanogpt-fork remote set-url origin git@github.com:videh-mnemonic/modded-nanogpt-fork.git \
    && git -C /workspace/modded-nanogpt-checkpoints remote set-url origin git@github.com:videh-mnemonic/modded-nanogpt-checkpoints.git \
    && git config --global --add safe.directory /workspace/modded-nanogpt-fork \
    && git config --global --add safe.directory /workspace/modded-nanogpt-checkpoints

RUN python3 -m venv /opt/venv \
    && python -m pip install --upgrade pip \
    && python -m pip install -r /workspace/modded-nanogpt-checkpoints/requirements.txt \
    && if [ "$TARGETARCH" = "amd64" ]; then \
        python -m pip install --pre torch --index-url https://download.pytorch.org/whl/nightly/cu126 --upgrade; \
    fi

WORKDIR /workspace/modded-nanogpt-checkpoints

VOLUME ["/workspace"]

CMD ["bash"]
