#!/bin/sh
# session-cycle.sh <prev|next> — salta a la sesión ANTERIOR / SIGUIENTE sin anidar.
# Lo invoca un keybind (Alt-[ / Alt-]) con la acción `Run` de Zellij.
#
# Zellij no tiene una acción nativa de "sesión siguiente/anterior", así que aquí
# calculamos el destino a partir de `zellij list-sessions` y la sesión actual, y
# cambiamos vía el plugin zellij-switch (mismo mecanismo, sin anidar, que usa zjcwd).

dir="${1:-next}"
[ "$dir" = prev ] || dir=next   # normaliza cualquier valor que no sea "prev" → "next"

# sesión actual: de la env var que Zellij inyecta en cada pane; si `Run` no la
# propagó, la sacamos del marcador "(current)" de list-sessions.
cur="${ZELLIJ_SESSION_NAME:-}"
[ -n "$cur" ] || cur=$(zellij list-sessions --no-formatting 2>/dev/null | grep '(current)' | awk '{print $1}')

# nombres de sesiones VIVAS (primer token de cada línea), sin las EXITED, ordenados
# alfabéticamente → orden de ciclo estable y predecible.
sessions=$(zellij list-sessions --no-formatting 2>/dev/null | grep -v 'EXITED' | awk 'NF{print $1}' | sort -u)
[ -n "$sessions" ] || exit 0

# recorre la lista en orden buscando el vecino de `cur`, con wrap-around (POSIX sh).
target=""; prev=""; first=""; last=""; take_next=0
IFS='
'
for s in $sessions; do
  [ -z "$first" ] && first="$s"
  last="$s"
  [ "$take_next" = 1 ] && { target="$s"; take_next=0; }
  if [ "$s" = "$cur" ]; then
    if [ "$dir" = prev ]; then target="$prev"; else take_next=1; fi
  fi
  prev="$s"
done
# wrap-around: si `cur` era el extremo, saltar al otro extremo.
[ "$dir" = next ] && [ -z "$target" ] && target="$first"
[ "$dir" = prev ] && [ -z "$target" ] && target="$last"

# nada que hacer si hay una sola sesión (o no cambia el destino).
[ -n "$target" ] && [ "$target" != "$cur" ] || exit 0

zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" -- "--session $target"
