# setup-sendio

GitHub Action that installs the [send.io](https://www.send.io) CLI on any
Linux, macOS or Windows runner (x64 or ARM64), verifies the release checksum,
and puts `sendio` on `PATH`.

```yaml
- uses: send-io/setup-sendio@v1 # repo name not final until the Marketplace release
  id: sendio
  with:
    version: latest # or e.g. 1.2.3
    api-key: ${{ secrets.SENDIO_API_KEY }} # optional; exported masked as SENDIO_API_KEY

- run: sendio --version
- run: echo "installed ${{ steps.sendio.outputs.version }}"
```

Create the key on the [API keys page](https://app.send.io/integrations/api-keys)
and store it as the repository secret `SENDIO_API_KEY`.

## Email the team when a deploy finishes

```yaml
on:
  push:
    branches: [main]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: send-io/setup-sendio@v1
        with:
          api-key: ${{ secrets.SENDIO_API_KEY }}
      - run: |
          sendio emails send \
            --from "Deploys <deploys@yourdomain.com>" \
            --to team@yourdomain.com \
            --subject "Deployed ${GITHUB_SHA::7}" \
            --text "${GITHUB_REPOSITORY} at ${GITHUB_SHA} was deployed by ${GITHUB_ACTOR}." \
            --wait delivered
```

`--wait delivered` fails the step if the email bounces.

## Keep email templates in the repository

```yaml
- uses: actions/checkout@v4
- uses: send-io/setup-sendio@v1
  with:
    api-key: ${{ secrets.SENDIO_API_KEY }}
- run: sendio templates push ./emails
```

## Inputs and outputs

| Input | Default | |
|---|---|---|
| `version` | `latest` | sendio version to install, e.g. `1.2.3` |
| `api-key` | none | exported, masked, as `SENDIO_API_KEY` for later steps |
| `repo` | `send-io/cli` | GitHub repo that hosts the sendio releases |
| `github-token` | the job token | used for the latest-release lookup |

Outputs: `version` (the installed version) and `path` (the binary).
