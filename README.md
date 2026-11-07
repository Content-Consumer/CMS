# CMS

## Developing Locally

### Prerequisites

- Elixir / Mix
- Node.js (for assets)
- Docker + Docker Compose (for Postgres)

### First-time setup

**1. Start Postgres**

```bash
docker-compose up -d
```

This starts Postgres on port `5432` and Adminer (DB GUI) on port `8080`.

**2. Install dependencies**

```bash
mix deps.get
```

**3. Set up the database**

```bash
mix ecto.setup
```

This creates the database and runs all migrations, including those owned by extensions like Deliberation.

**4. Build assets**

```bash
mix assets.setup && mix assets.build
```

**5. Start the server**

```bash
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000).

---

### Day-to-day

Start Postgres if not running, then from the **umbrella root**:

```bash
docker-compose up -d
mix phx.server
```

> **Important:** Always run commands from the **umbrella root** (`cms/`), not from `apps/wiki`. Running from `apps/wiki` only loads the wiki app and its dependencies — extension modules like `Deliberation` won't be on the code path and the server will crash.

---

### Resetting the database

```bash
mix ecto.reset
```

Drops the DB, recreates it, and runs all migrations. Restart the server afterward — on startup it reinstalls all extensions automatically.

---

### Running only migrations

```bash
mix wiki.migrate
```

Runs both core wiki migrations and all extension-owned migrations.
