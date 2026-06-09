#!/usr/bin/env bash
# Build the DroneX design document into a distributable PDF.
# Pipeline: Markdown -> (pandoc) HTML body -> wrap with cover -> (weasyprint) PDF.
# Requires: pandoc, weasyprint.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$REPO_ROOT/architecture"
SRC="$ARCH/DESIGN_DRONEX_MESH.md"
PDF="$ARCH/DESIGN_DRONEX_MESH.pdf"
TMP_HTML="$ARCH/.dronex_build.html"
TMP_BODY="$ARCH/.dronex_body.html"

command -v pandoc >/dev/null     || { echo "pandoc not found";     exit 1; }
command -v weasyprint >/dev/null || { echo "weasyprint not found"; exit 1; }

cleanup() { rm -f "$TMP_HTML" "$TMP_BODY"; }
trap cleanup EXIT

# 1. Markdown body -> HTML fragment (implicit_figures turns lone images into captioned figures)
pandoc "$SRC" -f markdown+implicit_figures -t html5 --no-highlight -o "$TMP_BODY"

# 2. Assemble cover + body into a standalone document (CSS + assets resolve relative to $ARCH)
{
  cat <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="print.css">
</head>
<body>
<section class="cover">
  <div class="kicker">Hecate Services · Working Design</div>
  <h1>DroneX</h1>
  <div class="rule"></div>
  <p class="lede">Federated counter-UAS airspace awareness on the Macula capability mesh.
  Turning a fleet of cheap, heterogeneous sensors into one coherent airspace picture, with no cloud and no single point of failure.</p>
  <div class="meta">
    <strong>hecate-services/hecate-dronex</strong><br>
    Status: Draft / Concept<br>
    2026-06-09
  </div>
  <div class="scope">Scope: detect · classify · track · alert.
  Defensive situational awareness only. No interference with aircraft.</div>
</section>
HTML
  cat "$TMP_BODY"
  echo '</body></html>'
} > "$TMP_HTML"

# 3. Render PDF
weasyprint "$TMP_HTML" "$PDF"

echo "Built: $PDF"
