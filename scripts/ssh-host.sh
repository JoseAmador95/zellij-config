#!/bin/sh
# ssh-host.sh — es el `default_shell` de una sesión "ssh_<host>": cada pane/tab nuevo entra
# por SSH al host (en vez de un shell local). Lo cablea `zjssh` (shell/functions.sh) vía
# `zellij attach … options --default-shell`.
#
# Por qué un wrapper: `default_shell` de Zellij acepta UN binario, no "ssh host" con argumento,
# así que el host se resuelve aquí (mismo patrón que scripts/agent.sh).
#
# BLINDAJE (bug: un tab nuevo en OTRA sesión —p.ej. `main`— abría el host SSH): sólo
# conectamos si el pane pertenece de verdad a una sesión "ssh_<host>" (ZELLIJ_SESSION_NAME
# empieza por "ssh_"). Si este wrapper acaba siendo el default_shell de otra sesión, o
# hereda un ZJ_SSH_HOST que no le toca, abrimos un shell local normal — NUNCA SSH.
#
# Host (ya dentro de una sesión ssh_):
#   1) $ZJ_SSH_HOST                     host real que fija `zjssh` (permite user@host, -A…);
#                                       por-sesión (el server de esa sesión lo hereda)
#   2) derivado de $ZELLIJ_SESSION_NAME (quita "ssh_"; sólo hosts simples, p.ej. tras
#                                       serialización cuando ZJ_SSH_HOST ya no está)
#
# Nota: el host remoto NO corre Zellij (aquí sólo el cliente) → shell remoto plano, sin anidar.
set -u

# ¿Estamos en una sesión "ssh_<host>"? Si no, jamás hacemos SSH.
case "${ZELLIJ_SESSION_NAME:-}" in
  ssh_?*) ;;
  *) exec "${SHELL:-/bin/sh}" -l ;;
esac

host="${ZJ_SSH_HOST:-}"
[ -n "$host" ] || host=${ZELLIJ_SESSION_NAME#ssh_}

# El pane ES la conexión: al salir (exit/logout) se cierra el tab, como un shell normal.
# `$host` sin comillas → word-splitting a propósito, permite valores tipo "-A host".
# shellcheck disable=SC2086
exec ssh $host
