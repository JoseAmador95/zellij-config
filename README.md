# Zellij config (reproducible, macOS + Linux)

Config de Zellij armonizada con **nvim (vscode.nvim light) + Ghostty + zsh**, pensada para
**SSH · nvim · Claude Code · vim-motions**. Modo `locked` por defecto con prefijo `Ctrl-a`
(estilo tmux/unlock-first).

## Puesta en marcha en una máquina nueva

```sh
git clone <este-repo> ~/.config/zellij
cd ~/.config/zellij
./bootstrap.sh
```

`bootstrap.sh` (idempotente, POSIX sh) hace:
1. Genera `config.kdl`, `layouts/main.kdl`, `layouts/dev.kdl` y `permissions.kdl` desde
   `templates/*.tmpl`, sustituyendo `__HOME__` por tu `$HOME` real. Necesario porque **Zellij
   no expande `~`/`$HOME`** en rutas de plugin ni el sessionizer en `root_dirs`.
2. Descarga los plugins `.wasm` a versión fija.
3. `chmod +x` a los scripts de la barra.
4. Siembra los permisos de plugin en la caché del SO (macOS `~/Library/Caches/...`,
   Linux `~/.cache/zellij/`) para evitar los prompts de permiso.

## ✍️ Cómo editar la config

Los archivos con rutas absolutas son **generados** (y están en `.gitignore`). **Edita las
plantillas** y re-genera:

```sh
$EDITOR templates/config.kdl.tmpl     # (o main.kdl.tmpl / dev.kdl.tmpl / permissions.kdl.tmpl)
./bootstrap.sh                        # regenera los archivos reales
```

Usa `__HOME__` donde vaya una ruta bajo tu home. Los `scripts/*.sh` no llevan rutas absolutas
(usan `hostname` / `$ZELLIJ_SESSION_NAME`), así que se editan directo.

## Plugins (versiones fijas)

| Plugin | Repo | Tag | Para qué |
|---|---|---|---|
| zjstatus | dj95/zjstatus | v0.24.0 | barra superior (modo, host, sesión, tabs) |
| zellij-sessionizer | laperlej/zellij-sessionizer | v0.5.0 | `Alt-g` — abrir proyecto de `~/Repositories` |
| zj-which-key | johnae/zj-which-key | v0.2.0 | hints de mappings (auto + `Alt-/` browser) |
| zellij-palette | timonwong/zellij-palette | v0.2.2 | `Alt-space` — command palette |
| zellij-switch | mostafaqanbaryan/zellij-switch | 0.2.1 | cambiar/crear sesión con `cwd` desde dentro (usado por `zjcwd`) |

Para actualizar un plugin: cambia su `tag` en el manifest dentro de `bootstrap.sh` y re-ejecuta.

## Atajos propios (esquema Alt, activos incluso en locked)

```
Ctrl-a        despertar Zellij (→ Normal) · Ctrl-a Ctrl-a → Locked
Alt-hjkl      foco entre panes/tabs        Alt-n   panel nuevo
Alt-1…9       ir al tab N
Alt-g         sessionizer (proyectos)      Alt-s   session-manager (sesiones)
Alt-space     command palette              Alt-/   which-key (cheatsheet)
```
En Normal, letras sueltas abren submodos (tmux): `p`ane `t`ab `r`esize `s`croll `o` session `m`ove.

## Dependencias

`zellij` (0.44+), `curl`, `sed`, `cksum`, `hostname`, `zsh`. En macOS via Homebrew;
los plugins requieren Zellij ≥ 0.44.

## Piezas externas (NO viven en este repo)

Añádelas a mano en cada máquina:

- **Auto-start del shell** — en `~/.config/sh/rc.sh` (o `~/.zshrc`), en shell interactivo:
  ```sh
  if [ -z "$ZELLIJ" ] && [ -t 1 ]; then
    zellij attach -c main options --default-layout main && exit
  fi
  ```
  Adjunta/crea siempre la sesión `main` con nuestro layout; `&& exit` cierra la terminal al
  salir de Zellij. En macOS, si Brew no está en PATH para shells no-interactivos, mete
  `eval "$(/opt/homebrew/bin/brew shellenv)"` en `~/.zshenv`.

- **SSH agent forwarding estable** — si entras con `ssh -A` a un host que corre Zellij, el
  socket del agente forwardeado cambia en cada conexión y Zellij persiste los paneles con el
  socket viejo (muerto) → "no hay llaves". Fíjalo a una ruta estable en `~/.config/sh/rc.sh`,
  **antes** del auto-start de arriba:
  ```sh
  if [ -n "$SSH_CONNECTION" ]; then
    if [ -S "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]; then
      ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
    fi
    [ -S "$HOME/.ssh/agent.sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
  fi
  ```
  El symlink `~/.ssh/agent.sock` se re-apunta en cada login → los paneles (que guardan esa
  ruta fija) se auto-curan al reconectar. Paneles ya abiertos: una vez
  `export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"`. Hay que ponerlo en cada host al que entres
  por SSH. Ojo seguridad: root en el host puede usar tu agente mientras estás conectado.

- **Función `zjcwd`** — en `~/.config/sh/rc.sh`, crea/salta a una sesión en el directorio
  actual SIN anidar (`zellij -s` anida estando dentro de Zellij):
  ```sh
  zjcwd() {
    local name="${PWD##*/}"; name="${name//./_}"
    if [ -n "$ZELLIJ" ]; then
      zellij pipe --plugin "file:$HOME/.config/zellij/plugins/zellij-switch.wasm" \
        -- "--session $name --cwd $PWD --layout dev"
    else
      zellij -s "$name" -n dev
    fi
  }
  ```

- **SSH sin anidar Zellij** — si el host local y el remoto corren Zellij, entrar por `ssh`
  desde dentro de Zellij local **anida** (dos barras), porque `$ZELLIJ` no se reenvía. Setup
  "el remoto gana" (persistencia remota): (1) el auto-start local respeta `NO_ZELLIJ`
  (`[[ -z "$ZELLIJ" && -z "$NO_ZELLIJ" ]]`); (2) función `zssh` que lanza el ssh en una
  ventana Ghostty NUEVA sin Zellij local, así el Zellij del remoto es el workspace sin anidar:
  ```sh
  zssh() {
    if command -v ghostty >/dev/null 2>&1; then
      ghostty -e ssh "$@" >/dev/null 2>&1 & disown   # Linux / ghostty en PATH
    else
      open -na Ghostty --args -e ssh "$@"            # macOS (app bundle)
    fi
  }
  ```
  Uso: `zssh mmja`. Para un shell local plano manual: abre el terminal con `NO_ZELLIJ=1`.

- **Ghostty `Shift+Enter`** — en `~/.config/ghostty/config`:
  ```ini
  keybind = shift+enter=text:\x1b\r
  ```
  Necesario para salto de línea en Claude Code/nvim (Zellij aplana el protocolo Kitty).

## Notas

- La barra muestra `[MODO] [🦀 host] [📁 sesión] [tabs]`. host y sesión llevan color+emoji
  **deterministas por hash** (mismo nombre → mismo look), vía `scripts/hostname-color.sh` y
  `scripts/session-color.sh`.
- `config.kdl.verbose.bak` / `config.kdl.bak` son respaldos locales (ignorados por git).
