#!/usr/bin/env bash
# Build DroneX design documents into distributable PDFs.
# Pipeline per doc: Markdown -> (pandoc) HTML body -> cover (from YAML front
# matter) -> (weasyprint) PDF.
# Usage:
#   scripts/build-pdf.sh                       # build every architecture/DESIGN_*.md
#   scripts/build-pdf.sh DESIGN_DRONEX_MESH.md # build one (name or path)
# Requires: pandoc, weasyprint, python3.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$REPO_ROOT/architecture"

command -v pandoc >/dev/null     || { echo "pandoc not found";     exit 1; }
command -v weasyprint >/dev/null || { echo "weasyprint not found"; exit 1; }
command -v python3 >/dev/null    || { echo "python3 not found";    exit 1; }

build_one() {
  local src="$1"
  local base; base="$(basename "$src" .md)"
  local pdf="$ARCH/$base.pdf"
  local body="$ARCH/.${base}.body.html"
  local cover="$ARCH/.${base}.cover.html"
  local doc="$ARCH/.${base}.build.html"
  trap 'rm -f "$body" "$cover" "$doc"' RETURN

  # 1. body fragment (implicit_figures -> captioned figures)
  pandoc "$src" -f markdown+implicit_figures -t html5 --no-highlight -o "$body"

  # 2. cover from YAML front matter
  python3 - "$src" > "$cover" <<'PY'
import sys, re, html
txt = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r'^---\n(.*?)\n---\n', txt, re.S)
f = {}
if m:
    for line in m.group(1).splitlines():
        if ':' in line:
            k, v = line.split(':', 1)
            f[k.strip()] = v.strip().strip('"').strip("'")
def g(k, d=''): return html.escape(f.get(k, d))
print(f'''<section class="cover">
  <div class="kicker">{g('kicker','Hecate Services · Working Design')}</div>
  <h1>{g('cover_title') or g('title')}</h1>
  <div class="rule"></div>
  <p class="lede">{g('lede')}</p>
  <div class="meta"><strong>{g('repo')}</strong><br>Status: {g('status')}<br>{g('date')}</div>
  <div class="scope">{g('scope')}</div>
</section>''')
PY

  # 3. assemble + render (CSS + assets resolve relative to $ARCH)
  {
    echo '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><link rel="stylesheet" href="print.css"></head><body>'
    cat "$cover"
    cat "$body"
    echo '</body></html>'
  } > "$doc"
  weasyprint "$doc" "$pdf"
  echo "Built: $pdf"
}

if [ "$#" -ge 1 ]; then
  case "$1" in
    /*) build_one "$1" ;;
    *)  build_one "$ARCH/$1" ;;
  esac
else
  for f in "$ARCH"/DESIGN_*.md; do build_one "$f"; done
fi
