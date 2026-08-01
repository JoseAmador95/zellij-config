#!/bin/sh
# session-bar.sh — lista NUMERADA de sesiones vivas para el widget {command_sessions} de
# zjstatus (va en format_right, ver layouts/*.kdl). Se consume con rendermode "dynamic",
# igual que hostname-color.sh.
#
# NO usa `zellij list-sessions` A PROPÓSITO, aunque sería más directo: ese comando es un
# CLIENTE de Zellij que abre sockets contra el servidor, y a este script lo lanza el propio
# servidor UNA VEZ POR TAB Y POR INTERVALO (el widget vive en default_tab_template). Aquí
# sólo se lee un directorio: cero procesos de zellij, cero conexiones nuevas.
#
# Fuente: Zellij mantiene un socket de dominio UNIX por sesión VIVA. Una salida limpia borra
# el suyo; sólo un crash o un kill -9 deja restos (una sesión fantasma en la barra, nunca un
# fallo). Las sesiones EXITED/resucitables no tienen socket: viven serializadas en la caché,
# así que no aparecen aquí, que es justo lo que queremos.
#
# Con `-v` imprime en stderr qué directorio encontró y qué nombres leyó (para depurar).
set -u

verbose=0
[ "${1:-}" = "-v" ] && verbose=1

# ── Localizar el directorio de sockets ───────────────────────────────────────
# $ZELLIJ_SOCK_DIR si Zellij lo exporta; si no, los sitios habituales. Se recogen los
# sockets del propio directorio Y de sus subdirectorios de un nivel (Zellij los agrupa por
# versión), así no hay que adivinar el número de versión ni elegir entre varias.
uid=$(id -u)
found_dir=""
sessions=""

for base in "${ZELLIJ_SOCK_DIR:-}" "${TMPDIR:-/tmp}/zellij-$uid" "/tmp/zellij-$uid" "${XDG_RUNTIME_DIR:-}/zellij" "/run/user/$uid/zellij"; do
  [ -n "$base" ] && [ -d "$base" ] || continue
  names=$(
    for f in "$base"/* "$base"/*/*; do
      [ -S "$f" ] && printf '%s\n' "${f##*/}"
    done 2>/dev/null | sort -u
  )
  if [ -n "$names" ]; then
    found_dir="$base"
    sessions="$names"
    break
  fi
done

if [ "$verbose" = 1 ]; then
  printf 'session-bar: directorio = %s\n' "${found_dir:-(ninguno)}" >&2
  printf 'session-bar: sesiones   = %s\n' "$(printf '%s' "$sessions" | tr '\n' ' ')" >&2
  printf 'session-bar: actual     = %s\n' "${ZELLIJ_SESSION_NAME:-(no llega la env var)}" >&2
fi

[ -n "$sessions" ] || exit 0

# Con una sola sesión no hay nada que elegir: el número sería redundante con la pastilla
# "📁 {session}" de format_left, y la derecha de la barra queda limpia.
[ "$(printf '%s\n' "$sessions" | wc -l)" -gt 1 ] || exit 0

# ── Pintar ───────────────────────────────────────────────────────────────────
# La sesión actual sale de $ZELLIJ_SESSION_NAME. Este script lo lanza el SERVIDOR (es un
# command widget de un plugin), no un pane, así que la variable puede no llegar; en ese caso
# se pinta la lista sin resaltar y la pastilla de format_left sigue diciendo dónde estás.
# Colores del tema vscode-light: la actual con la misma pastilla azul que {mode}, el resto
# en el gris del texto normal.
cur="${ZELLIJ_SESSION_NAME:-}"
i=0
out=""
OLDIFS=$IFS
IFS='
'
for s in $sessions; do
  i=$((i + 1))
  if [ "$s" = "$cur" ]; then
    out="$out#[bg=#007ACC,fg=#FFFFFF,bold] $i·$s #[default]"
  else
    out="$out#[fg=#343434] $i·$s #[default]"
  fi
done
IFS=$OLDIFS

printf '%s' "$out"
