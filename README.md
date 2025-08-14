# Infrastructure Scripts & Workflow Templates

This repo contains:

- **scripts/** – Bash helpers for:
  - **external/** – Downloading and managing external resources.
    - [`download-from-papermc.sh`](scripts/external/download-from-papermc.sh)
    - [`download-plugins.sh`](scripts/external/download-plugins.sh)
  - **internal/** – Managing internal resources.
    - [`replace-env-vars.sh`](scripts/internal/replace-env-vars.sh)
    - [`start_server.sh`](scripts/internal/start_server.sh)

- **.github/workflows/** – GitHub Actions templates you can include via [`uses:`](https://docs.github.com/actions/using-workflows/reusing-workflows) in your other repos.

## Usage

### [`download-plugins.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/download-plugins.sh)

```
./download-plugin.sh folder-that-has-the-json-files/*
```

#### To-do
- [ ] Automatic Plugin Updates

<!-- TODO Add Content how to add it & use it (Git Module) -->

## Building Docker Images Locally

You can build your Zrvr Docker image locally using the provided script:

```sh
chmod +x ./scripts/external/build-image.sh
./scripts/external/build-image.sh ./<service-folder>
```

Replace `<service-folder>` with the folder name of the service you want to build (e.g., `Lobby`, `Terra`, etc.).

This script will:
- Calculate a checksum of all shell scripts for cache busting.
- Build the Docker image with the correct build arguments.
