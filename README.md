# standard-notes-railway

Deployment images for running the [Standard Notes](https://standardnotes.com)
self-hosted sync server on [Railway](https://railway.com).

Standard Notes is an end-to-end encrypted notes app. This repository packages the
server side of it — the API gateway, auth, syncing, revisions and files servers,
and their workers — so it deploys on Railway without any manual setup step.

## Services

| Directory | Image | Role |
|---|---|---|
| `server/` | `standardnotes/server:latest` + Caddy | the sync server bundle, public |
| `web/` | `standardnotes/web:latest` | Standard Notes' own web client, pointed at the sync server, public |
| `localstack/` | `localstack/localstack:3.0` | SNS/SQS event bus between the servers and their workers, private |

All three are built from the repository root, selected with
`RAILWAY_DOCKERFILE_PATH=<dir>/Dockerfile`.

## What these images change

Upstream's bundle is written for `docker compose` on a VPS. Four things do not
carry over to Railway:

- **Logs.** Every component writes to a file under `/var/lib/server/logs`, so the
  platform's log stream shows nothing. `server/supervisord.conf` redirects all ten
  programs to stdout.
- **Two HTTP ports.** The API gateway listens on `3000` and the files server on
  `3104`, and clients fetch attachments straight from the second one. Railway
  publishes one domain per service, so `server/Caddyfile` joins both onto `$PORT`.
- **`PORT`.** Each server reads its own port from a generated `.env` file, and
  dotenv never overrides a variable already in the environment — so a platform
  `PORT` would make all five bind the same port. The entrypoint hands it to Caddy
  and unsets it.
- **Premium features.** Upstream's docs ask the operator to insert a subscription
  row by hand before file uploads or note history work. `server/grant-pro-plan.sh`
  does it for every account instead; set `GRANT_PRO_PLAN=false` to opt out.

## Configuration

The server takes upstream's environment variables unchanged — see
[the upstream entrypoint](https://github.com/standardnotes/server/blob/main/docker/docker-entrypoint.sh)
for the full list. The ones this deployment adds:

| Variable | Default | Meaning |
|---|---|---|
| `GRANT_PRO_PLAN` | `true` | grant every account the `PRO_USER` role and a `PRO_PLAN` subscription |
| `GRANT_PRO_PLAN_INTERVAL` | `60` | seconds between grant passes |
| `PUBLIC_FILES_SERVER_URL` | this deployment's public origin | where clients fetch attachments |

The web client takes two of its own:

| Variable | Default | Meaning |
|---|---|---|
| `SYNC_SERVER_URL` | none, required | the sync server's public URL; the container refuses to start without it rather than syncing to Standard Notes' hosted service |
| `FILES_HOST_URL` | `SYNC_SERVER_URL` | fallback attachment host when the server advertises none |

## Licence

The Standard Notes server is AGPL-3.0-or-later. This repository only contains
build and boot glue for it.
