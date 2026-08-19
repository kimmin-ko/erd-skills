#!/usr/bin/env bash
# Build a top-level index linking each per-schema Liam ERD, for a MySQL
# server whose schemas were each built separately with build-erd.sh.
#
#   ./build-schema-index.sh liam-erd shop billing analytics
#
# Expects "$OUT/<schema>/all/schema.json" to already exist for each schema
# (build-erd.sh's own "all" view).
set -euo pipefail

OUT=$1; shift
SCHEMAS=("$@")
[ ${#SCHEMAS[@]} -gt 0 ] || { echo "usage: build-schema-index.sh <outdir> <schema>..." >&2; exit 1; }

count_tables() {
  node -e "console.log(Object.keys(require('./$1/all/schema.json').tables||{}).length)" 2>/dev/null || echo '?'
}

{
  echo '<!doctype html><meta charset="utf-8"><title>Database ERD</title>'
  echo '<meta name="viewport" content="width=device-width,initial-scale=1">'
  echo '<style>body{font:16px/1.6 system-ui,sans-serif;max-width:44rem;margin:3rem auto;padding:0 1rem}'
  echo 'a{display:block;padding:.7rem 1rem;margin:.4rem 0;border:1px solid #ccc;border-radius:8px;'
  echo 'text-decoration:none;color:inherit}a:hover{background:#f4f4f5}code{color:#666;font-size:.85em}'
  echo '@media(prefers-color-scheme:dark){body{background:#18181b;color:#e4e4e7}'
  echo 'a{border-color:#3f3f46}a:hover{background:#27272a}code{color:#a1a1aa}}</style>'
  echo '<h1>Database ERD</h1><p>One MySQL schema (database) per link, each split by domain inside.</p>'
  for s in "${SCHEMAS[@]}"; do
    echo "<a href=\"./$s/\"><b>$s</b> <code>$(count_tables "$OUT/$s") tables</code></a>"
  done
} > "$OUT/index.html"

echo "wrote $OUT/index.html"
