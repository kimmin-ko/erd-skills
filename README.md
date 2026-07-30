# db-erd

An [Agent Skill](https://agentskills.io/home) that generates ERDs from a live database — for **Claude Code** and **Codex**.

It does not just draw a diagram. It measures the schema's foreign-key graph first, then picks the deliverable that will actually be readable: a single Mermaid diagram for small schemas, or domain-split interactive views for large ones.

## Why

Drawing 100 tables in one diagram produces something nobody can read. The usual advice — "split by domain" — leaves the hard part undone: *which* domains? Table-name prefixes lie. This skill derives domain boundaries from the FK graph, so the split reflects how the data is actually connected.

It also packages workflow knowledge that is not documented anywhere obvious, such as the fact that [Liam ERD](https://liambx.com) cannot read MySQL DDL at all and needs [tbls](https://github.com/k1LoW/tbls) as a bridge. See [`references/tool-notes.md`](skills/db-erd/references/tool-notes.md).

## Install

```bash
git clone https://github.com/<you>/db-erd-skill.git
cd db-erd-skill
./install.sh            # both agents; --claude or --codex for one
```

| Agent | Location |
|---|---|
| Claude Code | `~/.claude/skills/db-erd` (project: `.claude/skills/`) |
| Codex | `~/.agents/skills/db-erd` (project: `.agents/skills/`) |

Both agents read the same `SKILL.md` format, so one directory serves both. `./install.sh --uninstall` removes it.

## Requirements

- [`tbls`](https://github.com/k1LoW/tbls) — `brew install tbls`
- Node.js with `npx` (Liam is fetched on demand)

## Use

Ask your agent in natural language:

> Draw an ERD for the database at mysql://localhost:3306/shop

Or invoke it directly — `/db-erd` in Claude Code, `/skills` in Codex.

Supported databases are whatever `tbls` supports: MySQL, PostgreSQL, MariaDB, SQLite, SQL Server, Redshift, BigQuery, Spanner. Only the DSN changes.

## What it produces

Depending on what the measurement says:

- **Small schema** — a Mermaid `erDiagram` inline in markdown, version-controllable, renders anywhere
- **Large schema** — `liam-erd/` with one interactive zoomable view per derived domain, plus a context map and a full view
- **Optional** — `docs/schema/` markdown with a page and ER SVG per table (`tbls doc`)

Plus a review of what the FK graph reveals: orphaned tables, junction tables missing a composite UNIQUE, FKs left at default `RESTRICT`, status enums with no timestamps.

## Manual use

The scripts work without an agent:

```bash
export TBLS_DSN='mysql://user:pass@127.0.0.1:3306/dbname'
tbls out -t json -o tbls.json "$TBLS_DSN"

node skills/db-erd/scripts/gen-viewpoints.mjs tbls.json   # -> .tbls.yml
./skills/db-erd/scripts/build-erd.sh                      # -> liam-erd/
npx http-server -c-1 -p 8899 liam-erd                     # http://127.0.0.1:8899
```

`ERD_HUB_MIN=2` splits into more, smaller domains. `.tbls.yml` is generated but meant to be hand-edited afterward — rename domains, or split one that is still too big.

## Secrets

`.tbls.yml` is generated with `dsn: ${TBLS_DSN}`, never a literal password, so it is safe to commit. Generated output is gitignored — regenerate rather than commit it.

## License

MIT
