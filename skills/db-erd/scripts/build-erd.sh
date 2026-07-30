#!/usr/bin/env bash
# Build one interactive Liam ERD per domain viewpoint, plus a full-schema view.
#
#   TBLS_DSN='mysql://user:pass@127.0.0.1:3306/dbname' ./build-erd.sh [outdir]
#
# Requires: tbls, node/npx, network access for npx.
# Reads .tbls.yml and .erd-viewpoints.json produced by gen-viewpoints.mjs.
set -euo pipefail

OUT=${1:-liam-erd}
CFG=${ERD_CONFIG:-.tbls.yml}
VPS=$(dirname "$CFG")/.erd-viewpoints.json

: "${TBLS_DSN:?set TBLS_DSN (e.g. mysql://user:pass@127.0.0.1:3306/dbname)}"

for bin in tbls node npx; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done
[ -f "$CFG" ] || { echo "missing $CFG — run gen-viewpoints.mjs first" >&2; exit 1; }
[ -f "$VPS" ] || { echo "missing $VPS — run gen-viewpoints.mjs first" >&2; exit 1; }

# portable read into array (mapfile is bash 4+; macOS ships bash 3.2)
SLUGS=()
while IFS= read -r line; do
  [ -n "$line" ] && SLUGS+=("$line")
done < <(node -e "console.log(require('./$VPS').slugs.join('\n'))")
[ ${#SLUGS[@]} -gt 0 ] || { echo "no viewpoints in $VPS" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

count_tables() { node -e "console.log(Object.keys(require('./$1/schema.json').tables||{}).length)"; }

build() { # $1=input json  $2=slug
  npx -y @liam-hq/cli@latest erd build \
    --input "$1" --format tbls --output-dir "$OUT/$2" >/dev/null
  echo "  $2: $(count_tables "$OUT/$2") tables"
}

rm -rf "$OUT"
mkdir -p "$OUT"

echo "building ${#SLUGS[@]} domain views..."
for i in "${!SLUGS[@]}"; do
  # tbls out --viewpoint takes a 0-based index matching .tbls.yml order
  tbls out -c "$CFG" -t json --viewpoint "$i" -o "$TMP/vp$i.json"
  build "$TMP/vp$i.json" "${SLUGS[$i]}"
done

echo "building full-schema view..."
tbls out -c "$CFG" -t json -o "$TMP/all.json"
build "$TMP/all.json" all

{
  echo '<!doctype html><meta charset="utf-8"><title>Database ERD</title>'
  echo '<meta name="viewport" content="width=device-width,initial-scale=1">'
  echo '<style>body{font:16px/1.6 system-ui,sans-serif;max-width:44rem;margin:3rem auto;padding:0 1rem}'
  echo 'a{display:block;padding:.7rem 1rem;margin:.4rem 0;border:1px solid #ccc;border-radius:8px;'
  echo 'text-decoration:none;color:inherit}a:hover{background:#f4f4f5}code{color:#666;font-size:.85em}'
  echo '@media(prefers-color-scheme:dark){body{background:#18181b;color:#e4e4e7}'
  echo 'a{border-color:#3f3f46}a:hover{background:#27272a}code{color:#a1a1aa}}</style>'
  echo '<h1>Database ERD</h1><p>Interactive views split by domain.</p>'
  for s in "${SLUGS[@]}" all; do
    echo "<a href=\"./$s/\"><b>$s</b> <code>$(count_tables "$OUT/$s") tables</code></a>"
  done
} > "$OUT/index.html"

cat <<EOF

done -> $OUT
Liam output cannot be opened over file:// — serve it:
  npx http-server -c-1 -p 8899 $OUT   # then http://127.0.0.1:8899
EOF
