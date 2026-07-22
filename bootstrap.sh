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
#
# Flag --clean: reinstala limpio (re-baja plugins, regenera los .kdl y borra las sesiones
# serializadas). Úsalo cuando cambies un layout y no se refleje (ver aviso al final).
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

info() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

# --- 0) flags ----------------------------------------------------------------
CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --clean|-c) CLEAN=1 ;;
    -h|--help)
      printf 'uso: %s [--clean]\n' "$0"
      printf '  (sin flags)  genera archivos, baja los plugins que falten, siembra permisos\n'
      printf '  --clean, -c  reinstala limpio: re-baja plugins, regenera los .kdl y borra las\n'
      printf '               sesiones serializadas (para que un layout cambiado aplique)\n'
      exit 0 ;;
    *) warn "arg desconocido: $arg (ignorado)" ;;
  esac
done

echo "Zellij bootstrap → $DIR  (HOME=$HOME, $(uname -s))"
[ "$CLEAN" = 1 ] && info "modo --clean: reinstalación limpia"

# --- limpieza previa (--clean): fuerza regeneración y re-descarga ------------
if [ "$CLEAN" = 1 ]; then
  rm -f config.kdl layouts/main.kdl layouts/dev.kdl layouts/ssh.kdl permissions.kdl plugins/*.wasm
  info ".kdl generados y plugins/*.wasm borrados (se recrean abajo)"
fi

# --- 0b) resolver el shell que Zellij lanzará (default_shell) -----------------
# Un dato con dos usos: (a) el binario que Zellij abre en cada pane (default_shell de
# config.kdl) y (b) qué rc cablear en §5. Prioridad:
#   1) $ZELLIJ_DEFAULT_SHELL  override explícito (p.ej. un despliegue Ansible/appliance
#                             fuerza /bin/bash aunque $SHELL diga otra cosa)
#   2) $SHELL                 shell de login del host (lo normal en una máquina personal)
#   3) bash                   fallback: el más seguro (casi siempre presente; zsh puede faltar)
# Lo resolvemos a RUTA ABSOLUTA: Zellij lanza default_shell sin garantía del PATH del
# server, y este bootstrap ya materializa rutas absolutas por lo mismo (plugins, $HOME).
resolve_shell() {  # $1 = preferencia (ruta o nombre, puede venir vacía) → imprime ruta abs.
  _s="$1"
  case "$_s" in
    /*) if [ -x "$_s" ]; then printf '%s\n' "$_s"; return 0; fi ;;
    ?*) _p=$(command -v "$_s" 2>/dev/null || true)
        if [ -n "$_p" ]; then printf '%s\n' "$_p"; return 0; fi ;;
  esac
  _p=$(command -v bash 2>/dev/null || true)
  [ -n "$_p" ] || _p=$(command -v sh 2>/dev/null || true)
  [ -n "$_p" ] || _p=/bin/bash
  printf '%s\n' "$_p"
}
DEFAULT_SHELL=$(resolve_shell "${ZELLIJ_DEFAULT_SHELL:-${SHELL:-}}")

# Familia (para elegir el rc en §5): zsh si el binario es zsh; cualquier otro → bash.
case "$DEFAULT_SHELL" in
  *zsh) HOST_SHELL=zsh ;;
  *)    HOST_SHELL=bash ;;
esac
info "default_shell → $DEFAULT_SHELL  (familia $HOST_SHELL; ZELLIJ_DEFAULT_SHELL=${ZELLIJ_DEFAULT_SHELL:-∅}, \$SHELL=${SHELL:-∅})"

# --- 1) materializar plantillas (__HOME__ -> $HOME, __DEFAULT_SHELL__ -> ruta del shell) -------
gen() { mkdir -p "$(dirname "$2")"; sed -e "s|__HOME__|$HOME|g" -e "s|__DEFAULT_SHELL__|$DEFAULT_SHELL|g" "$1" > "$2"; }
gen templates/config.kdl.tmpl      config.kdl
gen templates/main.kdl.tmpl        layouts/main.kdl
gen templates/dev.kdl.tmpl         layouts/dev.kdl
gen templates/ssh.kdl.tmpl         layouts/ssh.kdl
gen templates/permissions.kdl.tmpl permissions.kdl
info "config.kdl, layouts/main.kdl, layouts/dev.kdl, layouts/ssh.kdl, permissions.kdl generados"

# --- 2) plugins pinneados (los .wasm son cross-platform) ---------------------
# repo|tag|asset
PLUGINS='dj95/zjstatus|v0.24.0|zjstatus.wasm
johnae/zj-which-key|v0.2.0|zj_which_key.wasm
timonwong/zellij-palette|v0.2.2|zellij-palette.wasm
mostafaqanbaryan/zellij-switch|0.2.1|zellij-switch.wasm'

mkdir -p plugins
is_wasm() { [ -s "$1" ] && [ "$(head -c4 "$1" | od -An -tx1 2>/dev/null | tr -dc '0-9a-f')" = "0061736d" ]; }
# NO usamos `... | while` (subshell): una descarga fallida debe abortar el bootstrap,
# y una bandera puesta dentro del subshell del pipe no sobreviviría. Iteramos en el
# shell actual partiendo por líneas (IFS=newline) y por '|' dentro de cada entrada.
fail=0
OLDIFS=$IFS
IFS='
'
for entry in $PLUGINS; do
  IFS='|'; set -- $entry; IFS=$OLDIFS
  repo=$1; tag=$2; asset=$3
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
      fail=1
    fi
  fi
done
IFS=$OLDIFS
[ "$fail" = 0 ] || { warn "abortando: faltan plugins (revisa red/tags arriba)"; exit 1; }

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

# --- 4b) (--clean) borrar sesiones serializadas ------------------------------
# Zellij resucita las sesiones con el layout que tenían al CREARSE; para que un
# layout cambiado aplique hay que borrar las serializadas. SIN --force: no toca
# sesiones vivas (p.ej. si corres esto desde dentro de Zellij).
if [ "$CLEAN" = 1 ] && command -v zellij >/dev/null 2>&1; then
  zellij delete-all-sessions --yes >/dev/null 2>&1 || true
  info "sesiones serializadas borradas (delete-all-sessions --yes)"
fi

# --- 5) sourcear las funciones de shell (zj, zjcwd) en el rc (idempotente) ----
# rc común (bash+zsh) si existe; si no, el rc propio del shell detectado del host.
if   [ -f "$HOME/.config/sh/rc.sh" ]; then RC="$HOME/.config/sh/rc.sh"
elif [ "$HOST_SHELL" = bash ];        then RC="$HOME/.bashrc"
else                                       RC="$HOME/.zshrc"
fi
if grep -qF '# >>> zj-functions >>>' "$RC" 2>/dev/null; then
  info "funciones de shell ya sourced en $RC"
else
  {
    printf '\n# >>> zj-functions >>>  (añadido por bootstrap.sh de Zellij)\n'
    printf 'source "$HOME/.config/zellij/shell/functions.sh"\n'
    printf '# <<< zj-functions <<<\n'
  } >> "$RC"
  info "source de funciones añadido a $RC"
fi

# --- 6) dependencias (aviso, no aborta) --------------------------------------
for dep in zellij curl cksum hostname sed; do
  command -v "$dep" >/dev/null 2>&1 || warn "falta '$dep' en PATH"
done

cat <<'EOF'

OK. Zellij es OPT-IN: no auto-arranca. Abre una terminal nueva y entra con:
  zj        → sesión 'main'          zjcwd → sesión en el directorio actual
  ssh mmja  → shell remoto plano → allí 'zj' para el Zellij remoto (sin anidar)

Ojo: los cambios de config/layout NO aplican a sesiones YA creadas (session_serialization).
Para forzarlos: sal de la sesión y corre  ./bootstrap.sh --clean  (borra las serializadas).

Layout 'dev': el tab 'agent' lanza tu agente de IA. Elígelo por host con
  export ZJ_AGENT=<cmd>   o   echo <cmd> > ~/.config/zellij/agent.local   (claude, codex, …)

Piezas EXTERNAS a este repo (añádelas a mano en cada host que uses):
  • SSH agent forwarding estable (bloque SSH_AGENT en ~/.config/sh/rc.sh) — ver README.
  • Ghostty (~/.config/ghostty/config) para Shift+Enter en Claude/nvim:
      keybind = shift+enter=text:\x1b\r
EOF
