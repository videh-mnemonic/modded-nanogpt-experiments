# modded-nanogpt-experiments

A CUDA development image for running Codex against
[`modded-nanogpt-checkpoints`](https://github.com/videh-mnemonic/modded-nanogpt-checkpoints).

The image contains:

- `modded-nanogpt-checkpoints` at `/workspace/modded-nanogpt-checkpoints`
- `modded-nanogpt-fork` at `/workspace/modded-nanogpt-fork`
- the Codex CLI
- the Python dependencies used by modded-nanogpt
- the SSH private key supplied at build time, installed as `/root/.ssh/id_ed25519`

## Security warning

The private SSH key is deliberately copied into the final image. Anyone who can
pull, export, inspect, or run the image can recover the key. Do not publish the
image to a public registry. The key is supplied as a BuildKit secret so it is not
stored in this repository or sent as a normal Docker build argument, but the
Dockerfile intentionally copies it into a persistent image layer.

## Build

Docker BuildKit is required. Set the key path and build the image:

```bash
export GITHUB_SSH_KEY="$HOME/.ssh/id_ed25519"
docker compose build
```

The equivalent direct build command is:

```bash
docker build \
  --secret id=github_ssh_key,src="$HOME/.ssh/id_ed25519" \
  --tag modded-nanogpt-experiments:latest \
  .
```

The default CUDA image targets Linux servers with NVIDIA GPUs. An AMD64 build
installs the project's CUDA 12.6 PyTorch wheel. A native Apple Silicon build uses
the ARM CPU wheel and is suitable only for structural validation; CUDA execution
requires an NVIDIA Linux host.

## Run

On a server with the NVIDIA Container Toolkit installed:

```bash
export GITHUB_SSH_KEY="$HOME/.ssh/id_ed25519"
docker compose run --rm experiments
```

The Compose configuration requests GPU access and creates named volumes for the
workspace and Codex state. Docker initializes a new empty workspace volume from
the copies baked into the image. Reuse the same volume names to retain commits,
checkpoints, downloads, and Codex login state across container replacements.

Inside the container, authenticate Codex if needed and start it:

```bash
codex login
codex
```

The default directory is `/workspace/modded-nanogpt-checkpoints`. Git pushes use
the embedded SSH key:

```bash
ssh -T git@github.com
git remote -v
git push
```

## Deploy without a registry

Build on a compatible Linux machine, then transfer the image archive:

```bash
docker save modded-nanogpt-experiments:latest | gzip > modded-nanogpt-experiments.tar.gz
scp modded-nanogpt-experiments.tar.gz user@server:/tmp/
```

On the server:

```bash
gzip -dc /tmp/modded-nanogpt-experiments.tar.gz | docker load
```

Copy this repository's `docker-compose.yml` to the server, set
`GITHUB_SSH_KEY` to any existing readable file (Compose requires the build
secret declaration even when the image is already built), and run the service.

## Refresh the repository snapshots

The repository clones are captured when the image is built. Rebuild with
`--pull --no-cache` to capture the latest default branches. Existing named
workspace volumes are not overwritten; create a new volume or pull changes from
inside the working checkout when updating an established container.
