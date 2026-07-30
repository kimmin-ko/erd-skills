# Tool notes

Verified against `tbls` 1.95.0, `@liam-hq/cli` 0.7.24, MySQL 8.0.46, macOS bash 3.2 (July 2026).
Each item below cost debugging time; none is documented where you would look first.

## Liam cannot read MySQL DDL

```
$ npx @liam-hq/cli erd build --help
--format <format>   (schemarb|postgres|prisma|drizzle|tbls|liam)
```

No `mysql`. A `mysqldump` file cannot be passed directly. `tbls` is the bridge: it introspects the live database and emits JSON that Liam accepts via `--format tbls`, preserving enums, indexes, and FK definitions with no lossy conversion.

Converting MySQL DDL to PostgreSQL DDL by hand also works but loses enum definitions and requires rewriting `KEY`/`AUTO_INCREMENT`/`ENGINE` clauses. Not worth it once `tbls` is available.

## tbls does not auto-discover its config

Passing `-c .tbls.yml` is mandatory even when the file sits in the current directory:

```bash
tbls doc --force              # ignores viewpoints, writes ./dbdoc/
tbls doc -c .tbls.yml --force # honors viewpoints and docPath
```

The failure is silent: the command exits 0 and produces a complete-looking full-schema document with no viewpoint pages. If viewpoints are missing from the output, check this first.

## `--viewpoint` is a 0-based index

```bash
tbls out -c .tbls.yml -t json --viewpoint 0 -o vp.json   # first viewpoint
```

Off-by-one produces a valid ERD of the wrong domain — no error to catch it. `build-erd.sh` keeps `.erd-viewpoints.json` in the same order as `.tbls.yml` so index and slug cannot drift.

## Liam output requires HTTP

The generated bundle fetches `schema.json` at runtime, which `file://` blocks. Liam prints this itself, but it is easy to miss:

```bash
npx http-server -c-1 -p 8899 liam-erd
```

`-c-1` disables caching, so a rebuild shows up on refresh.

## Mermaid validation is asymmetric headless

`mermaid.parse()` on an `erDiagram` works in plain Node. On a `flowchart` it fails with:

```
DOMPurify.addHook is not a function
```

That is a missing DOM, not a syntax error. Supply `jsdom` before importing mermaid, and do **not** assign `global.navigator` — it is a read-only getter in recent Node and throws.

## macOS bash is 3.2

`mapfile`/`readarray` do not exist. Use a portable loop:

```bash
SLUGS=()
while IFS= read -r line; do
  [ -n "$line" ] && SLUGS+=("$line")
done < <(node -e "...")
```

## Read the schema twice if it may be changing

A snapshot taken during a migration produces a confidently wrong ERD. Symptom: two counting methods disagree — e.g. `information_schema` reports 20 tables while `tbls` reports 138, because tables were being created between the two reads. Re-count until stable, and check `create_time`:

```sql
SELECT table_name, create_time FROM information_schema.tables
WHERE table_schema = DATABASE() ORDER BY create_time DESC LIMIT 10;
```

## Why hubs are claimed in ascending in-degree order

Descending order lets the largest hub claim nearly every table, collapsing the split back into one giant view. Ascending order gives specific hubs first refusal, so `invoices` keeps `payments` instead of losing it to `orders`.

A hub whose in-degree falls below `ERD_HUB_MIN` (default 3) is not promoted to its own domain and its children merge into whichever hub claims them. Lower the threshold with `ERD_HUB_MIN=2` to split more finely.
