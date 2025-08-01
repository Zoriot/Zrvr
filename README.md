# Infrastructure Scripts & Workflow Templates

This repo contains:

- **scripts/** – Bash helpers for:
    - [`download-paper.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/download-paper.sh)
    - [`download-velocity.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/download-velocity.sh)
    - [`download-plugins.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/download-plugins.sh)
    - [`replace-env-vars.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/replace-env-vars.sh)
    - [`copy.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/copy.sh)
    - [`start_server.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/start_server.sh)

- **.github/workflows/** – GitHub Actions templates you can include via [`uses:`](https://docs.github.com/actions/using-workflows/reusing-workflows) in your other repos.

## Usage

### [`download-plugins.sh`](https://github.com/Zoriot/Zrvr/blob/dev/scripts/download-plugins.sh)

```
./download-plugin.sh folder-that-has-the-json-files/*
```

#### To-do
- [ ] Automatic Plugin Updates

<!-- TODO Add Content how to add it & use it (Git Module) --!