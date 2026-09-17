# dbt Postgres Data Engineering Lab

Personal training repo for the **dbt Analytics Engineering certification exam** (Core **1.11**).

The warehouse is **PostgreSQL on a Raspberry Pi 5**. You develop on your laptop and run dbt against that instance.

The project started as the [Jaffle Shop](https://github.com/dbt-labs/jaffle-shop) sandbox (v2 / Fusion). It is **adapted for dbt Core 1.11** so it matches the exam engine, and for **Postgres on the Pi** instead of a cloud warehouse. Semantic Layer YAML (v2 spec) is commented out: Core 1.11 cannot parse it.

Use the **CLI + venv** in this folder. The dbt Labs editor extension talks to **Fusion** (`~/.local/bin/dbt`) and will segfault on Postgres Preview / LSP. That is expected; it is not how you run this lab.

## Stack

| Piece | Setup |
| --- | --- |
| Exam target | dbt Core **1.11.2** + `dbt-postgres` **1.11.0** |
| Warehouse | Postgres on a Raspberry Pi 5 |
| Profile name | `jaffle_shop` (`dbt_project.yml`) |
| Credentials | gitignored `.env` → `profiles.yml` via `env_var()` |
| Source data | CSVs in `seeds/jaffle-data` → schema `raw` |

## Clone

```bash
git clone https://github.com/Zekarim/dbt-postgres-data-engineering-lab.git
cd dbt-postgres-data-engineering-lab
```

## Python venv (Core, not Fusion)

Fusion on your PATH (`dbt-fusion 2.0.0-preview…`) is the wrong binary for this project.

```bash
python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install "dbt-core==1.11.2" "dbt-postgres==1.11.0"
```

There is no `dbt-postgres==1.11.2` on PyPI. `1.11.0` is the adapter that matches Core 1.11.

Check:

```bash
which dbt          # .../dbt-postgres-data-engineering-lab/.venv/bin/dbt
dbt --version      # Core 1.11.x, plugin postgres 1.11.0
```

Every new terminal:

```bash
cd /path/to/dbt-postgres-data-engineering-lab
source .venv/bin/activate
```

## `.env`

`.env` is gitignored. Create it in the project root (same folder as `dbt_project.yml`):

```bash
DBT_USER=dbt
DBT_PASSWORD=<postgres-password>
HOST=<raspberry-pi-ip-or-hostname>
```

| Variable | Used for |
| --- | --- |
| `HOST` | Pi address (`profiles.yml` → `host`) |
| `DBT_USER` | Postgres role |
| `DBT_PASSWORD` | Postgres password |

Core does **not** load `.env` by itself. Export it before any `dbt` command:

```bash
set -a && source .env && set +a
```

`set -a` exports every variable defined while sourcing. You need this in **every** shell session.

`DBT_ALLOW_EXPERIMENTAL_ADAPTERS` is a Fusion flag. You do not need it with Core.

## `profiles.yml`

Also gitignored. Create `profiles.yml` in this folder:

```yaml
jaffle_shop:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('HOST') }}"
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      port: 5432
      dbname: jaffle_shop
      schema: public
      threads: 4
```

Point dbt at **this** file (otherwise it uses `~/.dbt/profiles.yml`, often a Snowflake `default` profile):

```bash
export DBT_PROFILES_DIR="$(pwd)"
```

Postgres on the Pi must already have a database named `jaffle_shop` and a user that can create schemas (`raw`, and write to `public`).

## Session cheat sheet

```bash
cd /path/to/dbt-postgres-data-engineering-lab
source .venv/bin/activate
set -a && source .env && set +a
export DBT_PROFILES_DIR="$(pwd)"
```

Then:

```bash
dbt debug
```

You want `Connection test: [OK connection ok]`, not a segfault (segfault = Fusion still on PATH).

## Run the project

```bash
dbt deps
dbt seed --full-refresh --vars '{"load_source_data": true}'
dbt build
```

- **`seed`** loads `seeds/jaffle-data/*.csv` into schema **`raw`** (see `generate_schema_name` + `seeds.jaffle_shop.+schema: raw`).
- **`build`** creates staging **views** and mart **tables** in **`public`**, then runs tests.

Day-to-day:

```bash
dbt run
dbt test
dbt compile --select stg_customers
dbt show --select stg_customers --limit 20
dbt docs generate && dbt docs serve
```

## Inspect in SQL (psql)

```bash
psql "host=$HOST port=5432 dbname=jaffle_shop user=$DBT_USER"
```

```sql
SELECT schema_name FROM information_schema.schemata ORDER BY 1;

SELECT table_schema, table_type, table_name
FROM information_schema.tables
WHERE table_schema IN ('raw', 'public')
ORDER BY 1, 2, 3;

SELECT * FROM raw.raw_customers LIMIT 5;
SELECT * FROM public.stg_customers LIMIT 5;
```

## What was adapted from upstream Jaffle Shop

- `require-dbt-version: ">=1.11.0,<2.0.0"` (exam is Core 1.11, not Fusion v2)
- Profile `jaffle_shop` + env-based Postgres connection to the Pi
- dbt Cloud `project-id` removed (extension/Fusion was still hitting Snowflake)
- Semantic Layer / metrics / saved_queries / entities / dimensions commented out in `models/marts/*.yml` so Core 1.11 can parse

## Project layout

```
models/
  staging/          # views over raw sources (`source('ecom', ...)`)
  marts/            # customers, orders, order_items, …
macros/
seeds/jaffle-data/  # CSV seeds → schema raw
profiles.yml        # gitignored
.env                # gitignored
```

## Optional: more seed data

[`jafgen`](https://github.com/dbt-labs/jaffle-shop-generator) can generate extra years of CSVs. Still use the venv **after** `dbt-postgres` is installed, and keep sourcing `.env` + `DBT_PROFILES_DIR`.

```bash
python -m pip install -r requirements.txt
jafgen 6
rm -rf seeds/jaffle-data
mv jaffle-data seeds
dbt seed --full-refresh --vars '{"load_source_data": true}'
```
