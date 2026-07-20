#!/bin/sh
# agent.sh — resuelve QUÉ agente de IA lanzar en ESTE host (claude en casa, codex en el
# trabajo, …) y lo ejecuta. Lo usa el layout `dev` (tab "agent") y la función `agent` del
# shell (shell/functions.sh).
#
# Por qué un script y no un alias: un pane de Zellij (`pane command=`) ejecuta el binario
# DIRECTO, sin pasar por tu shell, así que un alias `agent` del .zshrc NO se vería aquí.
#
# Resolución EXPLÍCITA (sin autodetección) por precedencia:
#   1) $ZJ_AGENT                     ej.  export ZJ_AGENT="codex"  en tu rc por-host
#   2) ~/.config/zellij/agent.local  1ª línea útil; ej.  echo claude > …/agent.local
#   3) si nada resuelve → abre un shell con aviso (el pane queda usable, no muere)
set -u

cmd="${ZJ_AGENT:-}"

local_file="$HOME/.config/zellij/agent.local"
if [ -z "$cmd" ] && [ -f "$local_file" ]; then
  # 1ª línea útil: quita comentario inline (#…), recorta espacios y salta líneas vacías.
  # awk (no `sed '/./{p;q}'`, que BSD sed en macOS rechaza).
  cmd=$(awk '{ sub(/#.*/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") { print; exit } }' "$local_file")
fi

# Ejecuta el comando (permite argumentos: `exec $cmd` sin comillas hace word-splitting).
if [ -n "$cmd" ] && command -v "${cmd%% *}" >/dev/null 2>&1; then
  exec $cmd
fi

if [ -n "$cmd" ]; then
  printf 'agent.sh: "%s" no está en el PATH.\n' "${cmd%% *}" >&2
else
  printf 'agent.sh: define el agente con  export ZJ_AGENT=<cmd>  o  echo <cmd> > %s\n' "$local_file" >&2
fi
printf 'Abriendo un shell.\n' >&2
exec "${SHELL:-/bin/sh}" -l
