---
name: db-erd
description: Generate an ERD from a live database or DDL file — pick between a single Mermaid diagram and domain-split interactive views based on the schema's actual FK graph. Use when asked to draw, visualize, or document a database schema, produce an ER diagram, map table relationships, or answer "what does this database look like". Triggers on ERD, ER diagram, entity relationship, schema diagram, database visualization, 스키마 시각화, ERD 그려.
---

# Database ERD

Two deliverables, chosen by measuring the schema — never by guessing from table count alone.

## 1. Split by schema first, if there is more than one (MySQL)

In MySQL, "schema" and "database" are the same thing — one server commonly hosts several independent ones (`shop`, `billing`, `analytics`) with no FKs crossing between them. Merging their tables into one FK graph produces a diagram of several disconnected clusters glued together, which is worse than separate diagrams. And a DSN with no database segment, or the wrong one, silently draws only whatever `tbls` defaults to — never every schema on the server.

List what actually exists before assuming there is only one:

```bash
mysql -h HOST -P PORT -u USER -pPASS -N -e \
  "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA
   WHERE SCHEMA_NAME NOT IN ('information_schema','mysql','performance_schema','sys')"
```

If more than one comes back, run steps 2–4 **once per schema**, each with its own DSN (`mysql://user:pass@host:port/<schema>`), `.tbls.yml` (`gen-viewpoints.mjs ... --out .tbls-<schema>.yml --doc-path docs/schema/<schema>`), and Liam output dir (`./build-erd.sh liam-erd/<schema>`, with `ERD_CONFIG=.tbls-<schema>.yml`). Never mix tables from different schemas into one viewpoint. Once every schema has its own `liam-erd/<schema>/index.html`, link them from one top-level index:

```bash
./scripts/build-schema-index.sh liam-erd shop billing analytics
```

This step is MySQL/MariaDB-specific — PostgreSQL and SQL Server use "schema" for a namespace inside one database and normally need only one pass; ask if it's unclear which the user means.

## 2. Measure before choosing

Connect and count. `tbls` abstracts the driver, so this is the same for every supported DB:

```bash
export TBLS_DSN='mysql://user:pass@127.0.0.1:3306/dbname'
tbls out -t json -o tbls.json "$TBLS_DSN"
node scripts/gen-viewpoints.mjs tbls.json
```

The generator prints table count, FK count, detected hubs, and orphans. **Read that output before deciding.**

DSN schemes: `mysql://`(`my://`), `postgres://`(`pg://`), `mariadb://`, `sqlite:///path.db`, `mssql://`/`sqlserver://`, `redshift://`, `bigquery://`, `spanner://`. From a DDL file with no live DB, load it into a throwaway container first — `tbls` introspects databases, not SQL text.

## 3. Choose by hub degree, not table count

What breaks a single diagram is **one table having many children**, because Mermaid `erDiagram` has no way to position nodes — no subgraphs, no coordinates. Edge crossings explode and the SVG stretches past readability.

| Measurement | Deliverable |
|---|---|
| ≤30 tables **and** max hub in-degree ≤10 | Single Mermaid ERD, inline in markdown |
| 30–60 tables | Domain-split Mermaid, one diagram per domain + a domain-level context map |
| >60 tables, or any hub with >20 children | Interactive split views (step 4) — a single diagram is unreadable |

Prefer Mermaid when it fits: it is text, so it version-controls and renders in GitHub/GitLab/Notion/IDEs with no tooling. Only escalate when the measurement says it will not fit.

Validate any Mermaid you write — a diagram that fails to parse is worse than none:

```bash
node -e "const m=require('mermaid');m.default.parse(require('fs').readFileSync('d.mmd','utf8')).then(()=>console.log('OK'))"
```

`erDiagram` parses headless. `flowchart` needs a DOM — wire up `jsdom` or accept that a `DOMPurify.addHook is not a function` error is an environment limitation, not a syntax error.

## 4. Domain-split interactive views

```bash
./scripts/build-erd.sh              # -> liam-erd/, one view per domain + "all"
npx http-server -c-1 -p 8899 liam-erd
```

Then open http://127.0.0.1:8899. Optional markdown docs with per-table pages and ER SVGs:

```bash
tbls doc -c .tbls.yml --force       # -> docs/schema/
```

### How domains are derived

From the FK graph, not table names — prefixes lie, foreign keys do not.

1. A **hub** is any table referenced by ≥3 others (`ERD_HUB_MIN` to change).
2. Hubs claim their direct children in **ascending in-degree order**, so a specific hub (`invoices`) claims its children before a mega-hub (`orders`) swallows them.
3. Each hub's parents join as context; overlap between views is intentional.
4. Unclaimed tables become `reference` — lookups, rate tables, logs.

Coverage is asserted: if any table lands in no view, the generator exits non-zero. Hand-edit `.tbls.yml` afterward to rename or further split a domain — a domain over ~30 tables is still hard to read.

## 5. Verify, do not assume

- `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8899/<slug>/` for every view
- Cross-check the diagram's relationship count against the database:
  ```sql
  SELECT COUNT(*) FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE() AND referenced_table_name IS NOT NULL;
  ```
- Re-read the table count if the schema might be changing under you. A mid-migration snapshot silently produces a wrong ERD.

## 6. Report schema findings

The FK graph exposes real defects — surface them rather than only drawing:

- **Orphans** (no FK either direction) — the generator lists them. Logs and rate tables are legitimately unlinked; a business entity is not, and usually means a missing FK.
- **Junction tables without a composite UNIQUE** on their FK pair — allows duplicate pairs.
- **All FKs at default `RESTRICT`** — child tables fully owned by a parent often want `ON DELETE CASCADE`.
- **`status` enums with no timestamp columns** — makes point-in-time queries impossible.

## Tool quirks

These cost real debugging time; see `references/tool-notes.md` for detail.

| Quirk | Consequence |
|---|---|
| MySQL has no server-wide introspect mode | One DSN = one schema; a multi-schema server needs one `tbls out` per schema |
| Liam's `--format` has no `mysql` | MySQL DDL cannot be fed directly; `tbls` is the required bridge |
| `tbls` does not auto-discover its config | Omitting `-c .tbls.yml` silently ignores viewpoints and writes `dbdoc/` |
| Liam output rejects `file://` | Must be served over HTTP |
| `tbls out --viewpoint` is 0-based | Off-by-one silently builds the wrong domain |
| macOS ships bash 3.2 | No `mapfile`; scripts here use a portable read loop |

## Secrets

Never write a DSN into `.tbls.yml` — it is generated with `dsn: ${TBLS_DSN}` so the config is safe to commit. Keep generated output (`liam-erd/`, `docs/schema/`, `tbls.json`) out of git; regenerate it instead.
