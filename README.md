# Vaultwarden on Runsite

A one-click template that runs your own [Vaultwarden](https://github.com/dani-garcia/vaultwarden) password manager
on Runsite. Vaultwarden is a lightweight server compatible with the official Bitwarden apps: browser extensions,
desktop, iOS, Android and the CLI. It stores passwords, passkeys, 2FA codes, secure notes, file attachments and
Sends, and supports shared vaults for family and team. This repository is a thin wrapper around the official
`vaultwarden/server` image that keeps the vault in SQLite on a Runsite persistent disk and connects it to the
service's public URL.

[![Deploy on Runsite](https://img.shields.io/badge/Deploy%20on-Runsite-0f172a?style=for-the-badge)](https://dashboard.runsite.app/templates)

Deploying from the [Runsite template gallery](https://dashboard.runsite.app/templates) creates the web service and
a 1 GB disk mounted at `/data`, and wires every environment variable. No separate database is needed: a Nano
service with the disk runs a password manager for a family or a small team. Open `/admin` with
the `ADMIN_TOKEN`, invite yourself and create your account in the web vault.

- Runsite: https://runsite.app
- Dashboard: https://dashboard.runsite.app
- Docs: https://docs.runsite.app
- Template gallery: https://dashboard.runsite.app/templates
- Vaultwarden wiki: https://github.com/dani-garcia/vaultwarden/wiki

## What's inside

- **`Dockerfile`:** the official `vaultwarden/server` Alpine image pinned to a release (`VAULTWARDEN_VERSION`), on
  port 8080, with public sign-ups off, invitations on and the `Europe/Kyiv` time zone.
- **`deploy/entrypoint.sh`:** runs before Vaultwarden starts. It sets `DOMAIN` from `PUBLIC_URL`, uses SQLite on
  the disk unless `DATABASE_URL` is set and stops with a clear error when the disk is not writable.
- **`docker-compose.yml`:** a local copy of the Runsite setup: the Vaultwarden image and a volume for `/data`, plus
  an optional PostgreSQL profile.
- **`runsite-template.json`:** the template definition used in the Runsite template catalog.

## Deploy on Runsite

1. Click **Deploy on Runsite** above (or open Vaultwarden in the
   [template gallery](https://dashboard.runsite.app/templates)) and sign in.
2. Pick a project name and repository name, then click **Deploy**. Runsite copies this repository into your
   GitHub account, creates the web service and the disk and starts the first build.
3. The Nano plan is enough. Vaultwarden uses about 35 MB of memory when idle.
4. When the build finishes, open the [Runsite dashboard](https://dashboard.runsite.app): web service →
   **Environment** and copy `ADMIN_TOKEN`.
5. Create your account, see [First account](#first-account).

What the template sets for you:

| Variable | Value |
|---|---|
| `ADMIN_TOKEN` | 48 random characters, the password of the `/admin` panel |
| `PUBLIC_URL` | Public URL of the web service |

And the disk:

| Setting | Value |
|---|---|
| Mount path | `/data` |
| Size | 1 GB, can be increased later in the dashboard |

Anything else from the [Vaultwarden configuration](https://github.com/dani-garcia/vaultwarden/blob/main/.env.template)
can be added in the dashboard: web service → **Environment**. Saving redeploys the service.

## First account

Public sign-ups are off, so nobody else can create an account on your public URL. Accounts are created by
invitation:

1. Open `{PUBLIC_URL}/admin` and sign in with `ADMIN_TOKEN`.
2. Open **Users**, enter your email under **Invite User** and click **Invite**.
3. Open `{PUBLIC_URL}`, click **Create account** and register with the same email and a strong master password.

Without SMTP no email is sent: the invited address can register right away. Invite family members or colleagues
the same way. With SMTP configured (see [Email](#email)) they get an invitation email with a link.

The master password cannot be recovered or reset by the admin. If it is lost, the vault is lost too.

## Connecting the apps

In the Bitwarden browser extension, desktop or mobile app, choose **Self-hosted** (or the region selector →
**Self-hosted**) on the login screen and enter the service URL, for example
`https://vaultwarden-abc123.runsite.app`. Then sign in with your email and master password.

After you attach a custom domain, set `PUBLIC_URL` to it, for example `https://vault.example.com`, and use that URL
in the apps. Passkeys and WebAuthn 2FA are bound to the domain, so attach the custom domain before you set them up.

## The admin panel

`/admin` manages users, organizations, invitations and server settings. It is protected by `ADMIN_TOKEN`.

- Settings saved in the admin panel are written to `/data/config.json` and take priority over environment
  variables. To go back to the environment value, reset the setting in the panel.
- The token is stored in plain text, so Vaultwarden prints a notice about it in the logs. To replace it with an
  Argon2 hash, run `docker run --rm -it --entrypoint /vaultwarden vaultwarden/server hash` locally, put the result into
  `ADMIN_TOKEN` and redeploy.
- To turn the panel off, delete `ADMIN_TOKEN`.

## Data and backups

Everything lives on the disk at `/data`:

| File | What |
|---|---|
| `db.sqlite3` | Accounts, vault items, organizations, settings. Vault items are end-to-end encrypted by the apps. |
| `rsa_key.pem` | Signs login tokens. Without it every user is signed out. |
| `attachments/`, `sends/` | File attachments and Sends. |
| `config.json` | Settings saved in the admin panel. |

SQLite is Vaultwarden's default database and the most common way to run it. It handles thousands of vault items
and dozens of users without trouble; Vaultwarden runs as one instance, so a database server adds cost but no speed.

Keep your own backups:

- **Encrypted export:** in the web vault open **Tools → Export vault** and choose the encrypted JSON format. Do it
  regularly, it is the simplest backup and restores into any Bitwarden-compatible server.
- **Full server backup:** in the dashboard open web service → **Shell** and run `/vaultwarden backup`. It writes a
  consistent copy of the database to `/data/db_<date>_<time>.sqlite3`. Copy it together with `rsa_key.pem`,
  `attachments/` and `sends/` off the server, then delete old copies so they do not fill the disk.

Every device that is signed in also keeps an encrypted copy of the vault, so a short outage does not lock you out
of your passwords.

Vaultwarden refuses to start without a mounted volume at `/data`, and the entrypoint stops with an error when the
disk is not writable, so a missing disk shows up right away instead of losing data on the next redeploy.

## Email

Email is optional. It is needed for invitation emails, email 2FA, emergency access and password hints. Add these in
web service → **Environment** (or in `/admin` → **SMTP Email Settings**):

| Variable | Example |
|---|---|
| `SMTP_HOST` | `smtp.example.com` |
| `SMTP_PORT` | `587` |
| `SMTP_SECURITY` | `starttls` (or `force_tls` for port 465) |
| `SMTP_USERNAME` | `vault@example.com` |
| `SMTP_PASSWORD` | SMTP password |
| `SMTP_FROM` | `vault@example.com` |

## Configuration

Variables read by `deploy/entrypoint.sh`:

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | empty | Optional PostgreSQL connection, see [Using PostgreSQL](#using-postgresql). When empty, Vaultwarden uses SQLite in `/data/db.sqlite3`. |
| `PUBLIC_URL` | empty | Public URL of the service. Sets `DOMAIN`, which invite links, passkeys and attachment downloads need. |
| `ADMIN_TOKEN` | empty | Password of the `/admin` panel. Without it the panel is off. |
| `PORT` | empty | Overrides `ROCKET_PORT` when the service port is changed. |

Defaults set in the `Dockerfile`, each can be overridden in the environment:

| Variable | Default | Purpose |
|---|---|---|
| `ROCKET_PORT` | `8080` | Port Vaultwarden listens on. |
| `DATA_FOLDER` | `/data` | Folder on the persistent disk. Must match the disk mount path. |
| `SIGNUPS_ALLOWED` | `false` | Anyone with the URL can create an account. |
| `INVITATIONS_ALLOWED` | `true` | Admins and organization owners can invite users. |
| `SHOW_PASSWORD_HINT` | `false` | Shows the master password hint on the login page when SMTP is off. |
| `IP_HEADER` | `X-Forwarded-For` | Client IP header set by the Runsite ingress, used in logs and rate limits. |
| `DB_CONNECTION_RETRIES` | `90` | Seconds to wait for PostgreSQL before giving up. |
| `TZ` | `Europe/Kyiv` | Time zone of the server logs. |

To allow sign-ups only for your company, keep `SIGNUPS_ALLOWED=false` and set
`SIGNUPS_DOMAINS_WHITELIST=example.com`.

## Using PostgreSQL

For large organizations, or to use Runsite's managed database backups, Vaultwarden can store the vault in
PostgreSQL. The disk is still needed for `rsa_key.pem`, attachments and Sends.

1. Create a PostgreSQL database in the same Runsite project.
2. Set `DATABASE_URL` on the web service to the database's internal URL. URL-encoded passwords are supported.
3. Redeploy. Vaultwarden creates its tables on start.

Switching an existing server from SQLite does not move the data. Export the vault first and import it after the
switch, or set PostgreSQL up before anyone starts using the server.

## Updating Vaultwarden

The Vaultwarden version is pinned in the `Dockerfile`:

```dockerfile
ARG VAULTWARDEN_VERSION=1.37.4
```

Change it to a newer release from the [Vaultwarden releases](https://github.com/dani-garcia/vaultwarden/releases),
commit and push. Runsite rebuilds the service and Vaultwarden migrates the database on start. Take a database and
disk backup first (`/vaultwarden backup` in the **Shell** tab): migrations are not reversed when you go back to an
older version.

## Local development

Requirements: Docker.

```bash
docker compose up --build
```

Open http://localhost:8080/admin and sign in with `local-admin-token-change-me`, then invite yourself as described in
[First account](#first-account). If port 8080 is taken, run `VAULTWARDEN_PORT=8090 docker compose up --build`.
`docker compose down -v` stops the containers and deletes the data.

`docker compose --profile postgres up --build` also starts a second instance on http://localhost:8081 backed by
PostgreSQL. Its password contains `@`, `:`, `/` and `#`, so it checks that URL-encoded passwords work.

The web vault creates accounts only over HTTPS or on `localhost`, so open it by `localhost`, not by the machine's IP.

## Limitations

- **Single instance:** Vaultwarden runs as one replica. The disk can be attached to one service only.
- **Backups are yours:** the disk is not backed up automatically. See [Data and backups](#data-and-backups).
- **No SSO in the template:** OpenID Connect sign-in is supported by Vaultwarden but needs extra `SSO_*` variables.

## License

The files in this repository are MIT licensed. See `LICENSE`.

Vaultwarden itself is open source software by Daniel García and contributors, distributed under the
[GNU AGPL-3.0](https://github.com/dani-garcia/vaultwarden/blob/main/LICENSE.txt). It is not associated with
Bitwarden, Inc. Bitwarden is a trademark of Bitwarden, Inc.
