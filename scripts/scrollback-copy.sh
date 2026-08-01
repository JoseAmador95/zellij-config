#!/bin/sh
# scrollback-copy.sh — copia TODO el scrollback del pane actual al portapapeles.
# Se usa con la función `zjcopy` (shell/functions.sh) o con el atajo Ctrl-a y.
#
# POR QUÉ CORRE DENTRO DEL PANE Y NO DESDE UN KEYBIND:
# `zellij action dump-screen` vuelca el pane ENFOCADO, y la acción `Run` de un keybind abre
# un pane nuevo que se lleva el foco → volcaría ese pane, no el tuyo. La acción `DumpScreen`
# sí conserva el pane original, pero su parser de KDL tiene `include_scrollback: false`
# hardcodeado: sólo da lo visible en pantalla, no el scrollback. Por eso el atajo escribe
# `zjcopy` en el pane (WriteChars) en vez de lanzar un pane aparte.
set -u

[ -n "${ZELLIJ:-}" ] || { printf 'zjcopy: sólo funciona dentro de Zellij\n' >&2; exit 1; }

tmp=$(mktemp "${TMPDIR:-/tmp}/zjcopy.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT INT TERM

# --full = viewport + todo el scrollback (hasta scroll_buffer_size, 100k líneas).
# Sin --ansi: texto plano, que es lo que quieres pegar en otro sitio.
zellij action dump-screen --full --path "$tmp" || {
  printf 'zjcopy: falló `zellij action dump-screen` (¿Zellij < 0.44?)\n' >&2
  exit 1
}

bytes=$(wc -c < "$tmp" | tr -d ' ')
lines=$(wc -l < "$tmp" | tr -d ' ')

# OSC52 escribe en el portapapeles de TU máquina a través del terminal, así que es la única
# vía correcta por SSH (pbcopy/xclip del remoto copiarían al portapapeles del remoto). En
# local se prefiere la herramienta nativa: OSC52 lo trunca todo terminal a partir de cierto
# tamaño, y un scrollback largo se pasa de sobra.
osc52() {
  b64=$(base64 < "$tmp" | tr -d '\n')       # -w0 no es portable (BSD vs GNU): mejor tr
  printf '\033]52;c;%s\007' "$b64" > /dev/tty
  if [ "$bytes" -gt 100000 ]; then
    printf 'zjcopy: aviso — %s bytes por OSC52; muchos terminales truncan a partir de ~100 KB.\n' "$bytes" >&2
  fi
}

if [ -n "${SSH_TTY:-}${SSH_CONNECTION:-}" ]; then
  osc52; via="OSC52 (→ portapapeles local)"
elif command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$tmp"; via="pbcopy"
elif command -v wl-copy >/dev/null 2>&1; then
  wl-copy < "$tmp"; via="wl-copy"
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard < "$tmp"; via="xclip"
else
  osc52; via="OSC52"
fi

printf 'zjcopy: %s líneas (%s bytes) copiadas vía %s\n' "$lines" "$bytes" "$via"
