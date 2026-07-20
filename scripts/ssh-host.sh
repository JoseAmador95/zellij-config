#!/bin/sh
# ssh-host.sh — es el `default_shell` de una sesión "ssh_<host>": cada pane/tab nuevo entra
# por SSH al host (en vez de un shell local). Lo cablea `zjssh` (shell/functions.sh) vía
# `zellij attach … options --default-shell`.
#
# Por qué un wrapper: `default_shell` de Zellij acepta UN binario, no "ssh host" con argumento,
# así que el host se resuelve aquí (mismo patrón que scripts/agent.sh).
#
# Host, sin adivinar:
#   1) $ZJ_SSH_HOST                     lo fija `zjssh`; el server de Zellij lo hereda
#   2) derivado de $ZELLIJ_SESSION_NAME (quita el prefijo "ssh_"; sólo hosts simples)
#   3) si nada resuelve → abre un shell con aviso (el pane queda usable, no muere)
#
# Nota: el host remoto NO corre Zellij (aquí sólo el cliente) → shell remoto plano, sin anidar.
set -u

host="${ZJ_SSH_HOST:-}"
if [ -z "$host" ]; then
  case "${ZELLIJ_SESSION_NAME:-}" in
    ssh_?*) host=${ZELLIJ_SESSION_NAME#ssh_} ;;
  esac
fi

if [ -n "$host" ]; then
  # El pane ES la conexión: al salir (exit/logout) se cierra el tab, como un shell normal.
  # `$host` sin comillas → word-splitting a propósito, permite valores tipo "-A host".
  # shellcheck disable=SC2086
  exec ssh $host
fi

printf 'ssh-host.sh: sin host. Usa: zjssh <host>  (define ZJ_SSH_HOST).\n' >&2
exec "${SHELL:-/bin/sh}" -l
