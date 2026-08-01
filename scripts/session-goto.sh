#!/bin/sh
# session-goto.sh <N> — salta a la N-ésima sesión de la barra. Lo invoca Ctrl-a <dígito>
# (bloque `normal` de config.kdl) con la acción `Run` de Zellij.
#
# El índice sale de session-list.sh, el mismo orden que usa session-cycle.sh.
#
# El cambio de sesión va por el plugin zellij-switch, el mismo mecanismo que ya usan zjcwd,
# zjssh y session-cycle.sh. Zellij 0.44 tiene `zellij action switch-session`, pero ese lo
# ejecutaría un cliente CLI nuevo y no el cliente adjunto; el plugin corre DENTRO de la
# sesión y cambia el cliente correcto, que es lo que aquí hace falta.
set -u

n="${1:-}"
case "$n" in
  '' | *[!0-9]*) exit 0 ;;   # sin argumento o no numérico: no hacer nada
esac
[ "$n" -ge 1 ] || exit 0

dir=$(dirname "$0")
target=$(sh "$dir/session-list.sh" | sed -n "${n}p")

# Índice fuera de rango (menos sesiones que el dígito pulsado) o ya estás en ella.
[ -n "$target" ] || exit 0
[ "$target" != "${ZELLIJ_SESSION_NAME:-}" ] || exit 0

zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" -- "--session $target"
