#!/bin/sh
# session-bar.sh — lista NUMERADA de sesiones vivas para el widget {command_sessions} de
# zjstatus (va en format_right, ver layouts/*.kdl). Mismo patrón que hostname-color.sh:
# emite markup #[bg=…,fg=…] y se consume con  command_sessions_rendermode "dynamic".
#
# El índice que se pinta aquí es el que acepta  Ctrl-a <dígito>  (scripts/session-goto.sh):
# ambos leen el mismo orden de session-list.sh, así que siempre coinciden.
#
# Con una sola sesión no imprime nada: el número sería redundante con la pastilla
# "📁 {session}" que ya está en format_left, y la derecha de la barra queda limpia.
set -u

dir=$(dirname "$0")

sessions=$(sh "$dir/session-list.sh")
[ -n "$sessions" ] || exit 0

# Con una sola sesión no hay nada que elegir.
[ "$(printf '%s\n' "$sessions" | wc -l)" -gt 1 ] || exit 0

# Sesión actual, para resaltarla. OJO: este script lo lanza el SERVIDOR de Zellij (es un
# command widget de un plugin), no un pane, así que $ZELLIJ_SESSION_NAME puede no llegar; el
# marcador "(current)" de list-sessions es el respaldo. Si ninguno resuelve, se pinta la
# lista SIN resaltado y no se rompe nada: la pastilla de format_left sigue diciendo dónde estás.
cur="${ZELLIJ_SESSION_NAME:-}"
[ -n "$cur" ] || cur=$(zellij list-sessions --no-formatting 2>/dev/null | awk '/\(current\)/{print $1; exit}')

# Colores del tema vscode-light: la actual con la misma pastilla azul que usa {mode}, el
# resto en el gris del texto normal.
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
