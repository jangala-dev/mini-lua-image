# Fibers development image (Debian Bookworm)

This repository builds and publishes a Debian Bookworm–based container image intended for developing and testing the Fibers Lua runtime and its IO backends across `amd64` and `arm64`.

The image is published to GitHub Container Registry (GHCR) on each push to `main`, and can be used directly as a VS Code devcontainer image or as a CI runtime for Lua tooling.

## What the image contains

The image is based on `debian:bookworm-slim` and includes:

- Lua 5.1 and LuaJIT
- Common Lua modules used by Fibers development:
  - `lua-posix`
  - `lua-http`
  - `lua-cqueues`
  - `lua-bit32`
  - `lua-check`
- Two components built from source in a separate builder stage, then copied into the final runtime image:
  - `cffi-lua` (`cffi.so`) for Lua 5.1
  - `nixio` (`nixio.so` + Lua support files), used as an optional poll/select backend

The final image does **not** include the compiler toolchain; build-only dependencies live in the builder stage.

A non-root user (`vscode` by default) is created for use with VS Code Remote Containers / Dev Containers.

## Published tags

Images are published to GHCR as:

- `ghcr.io/jangala-dev/mini-lua-image:latest`
- `ghcr.io/jangala-dev/mini-lua-image:bookworm`

These tags are produced by the GitHub Actions workflow in this repository.

## Pulling the image

```sh
docker pull ghcr.io/jangala-dev/mini-lua-image:latest
# or
docker pull ghcr.io/jangala-dev/mini-lua-image:bookworm
````

## Running interactively

```sh
docker run --rm -it ghcr.io/jangala-dev/mini-lua-image:latest bash
```

Lua 5.1 and LuaJIT should be available:

```sh
lua -v
luajit -v
```

## Using as a VS Code devcontainer

In your Fibers source repository, create `.devcontainer/devcontainer.json` along the following lines:

```json
{
  "image": "ghcr.io/jangala-dev/mini-lua-image:latest",
  "remoteUser": "vscode",
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
```

If you prefer to build locally instead of pulling from GHCR, you can reference the Dockerfile directly:

```json
{
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  "remoteUser": "vscode"
}
```

## Contents and layout notes

### Multi-stage build

The Dockerfile uses two stages:

* `builder`: installs build tooling and compiles components not conveniently available as Debian packages.
* `final`: installs runtime dependencies only, then copies `/out/` from the builder stage.

### Installed paths

Compiled Lua modules are installed into:

* `/usr/local/lib/lua/5.1/` (native modules such as `cffi.so`, `nixio.so`)
* `/usr/local/share/lua/5.1/` (Lua support files)

This is compatible with the default Lua 5.1 search paths on Debian, and keeps locally-built modules separate from packaged ones.

## CI: build and publish

A GitHub Actions workflow builds and pushes multi-arch images to GHCR:

* Triggers:

  * on push to `main`
  * manual `workflow_dispatch`
* Platforms:

  * `linux/amd64`
  * `linux/arm64`

The workflow uses Buildx with QEMU to produce multi-platform manifests.

### Required permissions

The workflow requests:

* `contents: read`
* `packages: write`

and authenticates to GHCR using the repository-scoped `GITHUB_TOKEN`.

## Building locally

To build the image locally:

```sh
docker build -t mini-lua-image:bookworm .
```

To build multi-arch locally (requires Buildx and, usually, QEMU):

```sh
docker buildx build --platform linux/amd64,linux/arm64 -t mini-lua-image:multiarch .
```

## Customising the default user

The final stage creates a non-root user controlled by build args:

* `USERNAME` (default `vscode`)
* `USER_UID` (default `1000`)
* `USER_GID` (default equal to `USER_UID`)

Example:

```sh
docker build \
  --build-arg USERNAME=dev \
  --build-arg USER_UID=1001 \
  --build-arg USER_GID=1001 \
  -t fibres-dev:custom .
```

## Maintenance notes

* The `cffi-lua` and `nixio` builds are pinned to the default branch heads at build time (via shallow clone). If you need reproducible builds, pin to specific commit hashes.
* The final image installs `git`, `curl`, and `wget` to support common development workflows and CI tasks.
* This image is intended for development and CI. If you need a production runtime image, start from a minimal base and install only the modules required by your deployed firmware services.

## Licence

This repository contains the Dockerfile and build workflow used to assemble the image. Any third-party components included in the image remain under their respective licences:

* Debian packages: under their Debian/licence terms
* `cffi-lua`: see upstream repository
* `nixio`: see upstream repository
