# Funciones de shell del flujo Zellij. Se SOURCEA desde tu rc (lo cablea bootstrap.sh).
# Reproducible: vive en el repo (~/.config/zellij/shell/), no suelto en el rc.
# No lleva shebang a propósito: es para `source`, no para ejecutar.

# zjcwd — crea (o salta a) una sesión en el directorio ACTUAL, SIN anidar.
# Dentro de Zellij usa zellij-switch (cambia de sesión vía plugin, sin nesting,
# que es lo que `zellij -s` no puede hacer estando adjunto); fuera, el CLI normal.
zjcwd() {
  local name="${PWD##*/}"; name="${name//./_}"
  if [ -n "$ZELLIJ" ]; then
    zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" \
      -- "--session $name --cwd $PWD --layout dev"
  else
    zellij -s "$name" -n dev
  fi
}

# zjssh — ssh a un host que corre SU PROPIO Zellij, en ventana Ghostty NUEVA (sin
# Zellij local) → el Zellij del remoto es el workspace, SIN anidar. "Remoto gana".
# (La ventana corre `ssh` directo, no un login shell, así el auto-start local no dispara.)
zjssh() {
  if command -v ghostty >/dev/null 2>&1; then
    ghostty -e ssh "$@" >/dev/null 2>&1 & disown        # Linux / ghostty en PATH
  else
    open -na Ghostty --args -e ssh "$@"                 # macOS (app bundle)
  fi
}
