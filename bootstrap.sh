#!/bin/sh
# bootstrap.sh — instala/actualiza esta config de Zellij en la máquina actual.
# Funciona en macOS y Linux. Idempotente: re-ejecutable sin efectos adversos.
#
#   git clone <repo> ~/.config/zellij && cd ~/.config/zellij && ./bootstrap.sh
#
# Qué hace:
#   1) genera config.kdl / layouts / permissions.kdl desde templates/ con tu $HOME
#      (Zellij NO expande ~/$HOME en rutas de plugin, por eso hay que materializarlas)
#   2) descarga los plugins .wasm a una VERSIÓN FIJA
#   3) hace ejecutables los scripts de la barra
#   4) siembra los permisos de plugin en la caché del SO (evita los prompts)
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

info() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "Zellij bootstrap → $DIR  (HOME=$HOME, $(uname -s))"

# --- 1) materializar plantillas (__HOME__ -> $HOME) --------------------------
gen() { mkdir -p "$(dirname "$2")"; sed "s|__HOME__|$HOME|g" "$1" > "$2"; }
gen templates/config.kdl.tmpl      config.kdl
gen templates/main.kdl.tmpl        layouts/main.kdl
gen templates/dev.kdl.tmpl         layouts/dev.kdl
gen templates/permissions.kdl.tmpl permissions.kdl
info "config.kdl, layouts/main.kdl, layouts/dev.kdl, permissions.kdl generados"

# --- 2) plugins pinneados (los .wasm son cross-platform) ---------------------
# repo|tag|asset
PLUGINS='dj95/zjstatus|v0.24.0|zjstatus.wasm
laperlej/zellij-sessionizer|v0.5.0|zellij-sessionizer.wasm
johnae/zj-which-key|v0.2.0|zj_which_key.wasm
timonwong/zellij-palette|v0.2.2|zellij-palette.wasm'

mkdir -p plugins
is_wasm() { [ -s "$1" ] && [ "$(head -c4 "$1" | od -An -tx1 2>/dev/null | tr -dc '0-9a-f')" = "0061736d" ]; }
echo "$PLUGINS" | while IFS='|' read -r repo tag asset; do
  [ -n "$repo" ] || continue
  dest="plugins/$asset"
  if is_wasm "$dest"; then
    info "$asset ($tag) ya presente"
  else
    url="https://github.com/$repo/releases/download/$tag/$asset"
    if curl -fsSL -o "$dest" "$url" && is_wasm "$dest"; then
      info "$asset ($tag) descargado"
    else
      warn "no se pudo bajar/validar $asset ($url)"
    fi
  fi
done

# --- 3) scripts ejecutables --------------------------------------------------
chmod +x scripts/*.sh bootstrap.sh 2>/dev/null || true
info "scripts/*.sh +x"

# --- 4) sembrar permisos en la caché del SO ----------------------------------
case "$(uname -s)" in
  Darwin) CACHE="$HOME/Library/Caches/org.Zellij-Contributors.zellij" ;;
  *)      CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zellij" ;;
esac
mkdir -p "$CACHE"
cp permissions.kdl "$CACHE/permissions.kdl"
info "permisos sembrados → $CACHE/permissions.kdl"

# --- 5) dependencias (aviso, no aborta) --------------------------------------
for dep in zellij curl cksum hostname sed; do
  command -v "$dep" >/dev/null 2>&1 || warn "falta '$dep' en PATH"
done

cat <<'EOF'

OK. Piezas EXTERNAS a este repo (añádelas a mano en cada máquina):
  • Auto-start del shell (~/.config/sh/rc.sh o ~/.zshrc), en shell interactivo:
      if [ -z "$ZELLIJ" ] && [ -t 1 ]; then
        zellij attach -c main options --default-layout main && exit
      fi
  • Ghostty (~/.config/ghostty/config) para Shift+Enter en Claude/nvim:
      keybind = shift+enter=text:\x1b\r

Abre una terminal nueva para estrenar la sesión 'main'.
EOF
