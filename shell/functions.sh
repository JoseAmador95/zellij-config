# Funciones de shell del flujo Zellij. Se SOURCEA desde tu rc (lo cablea bootstrap.sh).
# Reproducible: vive en el repo (~/.config/zellij/shell/), no suelto en el rc.
# No lleva shebang a propósito: es para `source`, no para ejecutar.
#
# MODELO OPT-IN: Zellij NO auto-arranca. Entras a mano con `zj` (o `zjcwd`). Así, con
# SSH y Zellij en ambos hosts, la cadena tiene UN solo Zellij y `ssh` no anida.

# zj — abrir (adjuntar o crear) la sesión "main" con nuestro layout. Comando principal.
# `zj` → sesión "main"; `zj foo` → sesión "foo". Sin `&& exit`: al salir vuelves al shell.
zj() { zellij attach -c "${1:-main}" options --default-layout main; }

# agent — lanza el agente de IA de ESTE host (claude/codex/…). Mismo resolvedor que usa el
# layout `dev`. Config por-host: `export ZJ_AGENT=<cmd>` o `echo <cmd> > ~/.config/zellij/agent.local`.
agent() { "$HOME/.config/zellij/scripts/agent.sh"; }

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
