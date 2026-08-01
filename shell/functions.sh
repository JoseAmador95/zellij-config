# Funciones de shell del flujo Zellij. Se SOURCEA desde tu rc (lo cablea bootstrap.sh).
# Reproducible: vive en el repo (~/.config/zellij/shell/), no suelto en el rc.
# No lleva shebang a propósito: es para `source`, no para ejecutar.
#
# MODELO OPT-IN: Zellij NO auto-arranca. Entras a mano con `zj` (o `zjcwd`). Así, con
# SSH y Zellij en ambos hosts, la cadena tiene UN solo Zellij y `ssh` no anida.

# ── Límite de file descriptors ───────────────────────────────────────────────
# macOS trae un soft limit de 256 (`launchctl limit maxfiles`), que heredan Ghostty y todo
# shell que abras dentro. El servidor de Zellij hereda a su vez el del shell que lo arranca,
# y 256 NO da para una sesión con varios tabs: cada pane es un pty y cada tab una instancia
# de zjstatus. Al agotarlos, el servidor entero se cae con:
#
#   Thread 'server_listener' panicked … Os { code: 24, "Too many open files" }
#
# No es una fuga: es un techo demasiado bajo. El hard limit es `unlimited`, así que subir el
# soft no necesita sudo ni tocar launchd. Sólo SUBE (nunca baja) y se topa con el hard limit
# del sistema, que en Linux sí puede ser finito.
#
# OJO: sólo afecta a servidores NUEVOS. Una sesión ya viva conserva el límite con el que
# nació; para que aplique hay que cerrarla y volver a crearla.
_zj_raise_nofile() {
  local want=8192 cur hard
  cur=$(ulimit -Sn 2>/dev/null) || return 0
  [ "$cur" = unlimited ] && return 0
  [ "$cur" -ge "$want" ] 2>/dev/null && return 0
  hard=$(ulimit -Hn 2>/dev/null)
  if [ -n "$hard" ] && [ "$hard" != unlimited ] && [ "$hard" -lt "$want" ] 2>/dev/null; then
    want="$hard"
  fi
  ulimit -Sn "$want" 2>/dev/null || true
}
_zj_raise_nofile
unset -f _zj_raise_nofile 2>/dev/null

# zj — abrir (adjuntar o crear) la sesión "main" con nuestro layout. Comando principal.
# `zj` → sesión "main"; `zj foo` → sesión "foo". Sin `&& exit`: al salir vuelves al shell.
# "main" se crea SIN serialización (--session-serialization false): evita resucitar paneles
# zombi (p.ej. un `pane edit`/nvim que quede pegado y reviva en cada attach). Las demás
# sesiones respetan la config global (session_serialization true) y siguen sobreviviendo.
zj() {
  local s="${1:-main}"
  if [ "$s" = main ]; then
    zellij attach -c "$s" options --default-layout main --session-serialization false
  else
    zellij attach -c "$s" options --default-layout main
  fi
}

# agent — lanza el agente de IA de ESTE host (claude/codex/…). Mismo resolvedor que usa el
# layout `dev`. Config por-host: `export ZJ_AGENT=<cmd>` o `echo <cmd> > ~/.config/zellij/agent.local`.
agent() { "$HOME/.config/zellij/scripts/agent.sh"; }

# zjcopy — copia TODO el scrollback del pane actual al portapapeles. Atajo: Ctrl-a y (que
# escribe este mismo comando en el pane; ver el comentario de scripts/scrollback-copy.sh).
zjcopy() { "$HOME/.config/zellij/scripts/scrollback-copy.sh"; }

# zjcwd — crea (o salta a) una sesión rooteada en el directorio ACTUAL, SIN anidar.
# Dentro de Zellij usa zellij-switch (cambia de sesión vía plugin, sin nesting, que es lo
# que `zellij -s` no puede hacer estando adjunto); fuera, el CLI normal.
zjcwd() {
  local name="${PWD##*/}"; name="${name//./_}"
  if [ -n "$ZELLIJ" ]; then
    zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" \
      -- "--session $name --cwd $PWD --layout dev"
  else
    zellij -s "$name" -n dev
  fi
}

# zjssh <host> — sesión EXCLUSIVA para un host SSH: cada tab nuevo entra al host.
# Igual que zjcwd, NO anida: DENTRO de Zellij cambia de sesión vía zellij-switch (usar el CLI
# `attach` aquí anidaría un Zellij dentro de otro); FUERA, el CLI normal crea/adjunta.
# El remoto NO corre Zellij (aquí sólo el cliente) → shells remotos planos, sin anidar.
# Opciones por-host (usuario, puerto, -A) van en ~/.ssh/config, no aquí.
zjssh() {
  [ -n "$1" ] || { echo "uso: zjssh <host|alias-de-~/.ssh/config>"; return 1; }
  local host="$1" sess="ssh_${1//[^A-Za-z0-9_-]/_}"
  if [ -n "$ZELLIJ" ]; then
    # Dentro de Zellij: cambia de sesión SIN anidar (plugin). No puede pasar env ni
    # default_shell, así que el SSH lo hornea el layout `ssh`: sus panes corren ssh-host.sh,
    # que DERIVA el host del nombre ssh_<host> (usa alias de ~/.ssh/config). Ver layouts/ssh.kdl.
    # Ojo: los splits de pane (Alt-n) quedan como shell LOCAL; abre un TAB (Alt-t) para otro SSH.
    zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" \
      -- "--session $sess --layout ssh"
  else
    # Fuera de Zellij: CLI normal (adjunta o crea). $ZJ_SSH_HOST fija el host EXACTO (permite
    # user@host, -A…) y --default-shell hace que TODO pane nuevo (tabs Y splits) entre al host.
    ZJ_SSH_HOST="$host" zellij attach -c "$sess" \
      options --default-layout main \
              --default-shell "$HOME/.config/zellij/scripts/ssh-host.sh"
  fi
}
