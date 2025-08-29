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

### [`download-plugins.sh`](scripts/external/download-plugins.sh)

```
./download-plugin.sh folder-that-has-the-json-files/*
```
This script will read all the JSON files in the specified folder and download the plugins to a `plugins/` folder in the current directory.

### [`repo_maint.sh`](scripts/external/repo_maint.sh)

#### Pre requisites

# Debian/Ubuntu - replace 7zip with zstd/gzip if you want to use it
```
sudo apt-get update
sudo apt-get install -y tar p7zip-full rclone
rclone config   # create a remote named "gdrive" (or whatever you used in GDRIVE_REMOTE)
```
