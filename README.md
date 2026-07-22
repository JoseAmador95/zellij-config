# Zellij config (reproducible, macOS + Linux)

Config de Zellij armonizada con **nvim (vscode.nvim light) + Ghostty + zsh**, pensada para
**SSH · nvim · Claude Code · vim-motions**. Modo `locked` por defecto con prefijo `Ctrl-a`
(estilo tmux/unlock-first).

## Puesta en marcha en una máquina nueva

```sh
brew install zellij
git clone git@github.com:JoseAmador95/zellij-config.git ~/.config/zellij && cd ~/.config/zellij && ./bootstrap.sh
```

> Si el mac aún no tiene tu llave SSH, usa la URL HTTPS:
> `https://github.com/JoseAmador95/zellij-config.git`.

`bootstrap.sh` (idempotente, POSIX sh) hace:
1. Genera `config.kdl`, `layouts/main.kdl`, `layouts/dev.kdl`, `layouts/ssh.kdl` y
   `permissions.kdl` desde `templates/*.tmpl`, sustituyendo `__HOME__` por tu `$HOME` real y
   `__DEFAULT_SHELL__` por la **ruta absoluta** del shell que Zellij lanzará (`default_shell`),
   resuelta por prioridad `$ZELLIJ_DEFAULT_SHELL` › `$SHELL` › `bash` (p.ej. en un despliegue sin
   `$SHELL` fiable: `ZELLIJ_DEFAULT_SHELL=/bin/bash ./bootstrap.sh`).
   Necesario porque **Zellij no expande `~`/`$HOME`/`$PATH`** en esas rutas.
2. Descarga los plugins `.wasm` a versión fija (aborta si alguno no baja/valida).
3. `chmod +x` a los scripts de la barra.
4. Siembra los permisos de plugin en la caché del SO (macOS `~/Library/Caches/...`,
   Linux `~/.cache/zellij/`) para evitar los prompts de permiso.
5. Cablea las funciones de shell (`zj`, `zjcwd`, `agent`, `zjssh`) en el rc de la familia del
   shell resuelto: `~/.bashrc` o `~/.zshrc` (o `~/.config/sh/rc.sh` si existe).

**Reinstall limpio:** `./bootstrap.sh --clean` re-baja los plugins, regenera los `.kdl` y **borra las
sesiones serializadas**. Úsalo cuando cambies un layout y no se refleje: con `session_serialization`
Zellij resucita las sesiones con el layout que tenían al **crearse**, así que regenerar `layouts/dev.kdl`
no toca una sesión existente. `--clean` no mata sesiones vivas (sal de ellas primero si aplica).

## ✍️ Cómo editar la config

Los archivos con rutas absolutas son **generados** (y están en `.gitignore`). **Edita las
plantillas** y re-genera:

```sh
$EDITOR templates/config.kdl.tmpl     # (o main.kdl.tmpl / dev.kdl.tmpl / permissions.kdl.tmpl)
./bootstrap.sh                        # regenera los archivos reales
```

Usa `__HOME__` donde vaya una ruta bajo tu home (y `__DEFAULT_SHELL__` para la ruta del shell).
Los `scripts/*.sh` no llevan rutas absolutas (usan `hostname` / `$ZELLIJ_SESSION_NAME`), así que
se editan directo.

## Plugins (versiones fijas)

| Plugin | Repo | Tag | Para qué |
|---|---|---|---|
| zjstatus | dj95/zjstatus | v0.24.0 | barra superior (modo, host, sesión, tabs) |
| zj-which-key | johnae/zj-which-key | v0.2.0 | hints de mappings (auto + `Alt-/` browser) |
| zellij-palette | timonwong/zellij-palette | v0.2.2 | `Alt-space` — command palette |
| zellij-switch | mostafaqanbaryan/zellij-switch | 0.2.1 | cambiar/crear sesión desde dentro sin anidar (usado por `zjcwd` y `zjssh`) |

Para actualizar un plugin: cambia su `tag` en el manifest dentro de `bootstrap.sh` y re-ejecuta.

## Atajos propios (esquema Alt, activos incluso en locked)

```
Ctrl-a        despertar Zellij (→ Normal) · Ctrl-a Ctrl-a → Locked
Alt-hjkl      foco entre panes/tabs        Alt-n   panel nuevo
Alt-1…9       ir al tab N                  Alt-s   session-manager (sesiones)
Alt-space     command palette              Alt-/   which-key (cheatsheet)
Alt-[ Alt-]   sesión anterior/siguiente    Alt-t   tab nuevo
```
En Normal, letras sueltas abren submodos (tmux): `p`ane `t`ab `r`esize `s`croll `o` session `m`ove.

**Zellij es opt-in** (no auto-arranca). **Funciones de shell** (`shell/functions.sh`, sourced
automáticamente por `bootstrap.sh`):
- `zj` — abrir/entrar a la sesión `main` (adjunta o crea, con el layout). `zj foo` → sesión `foo`.
- `zjcwd` — crea/salta a una sesión rooteada en el directorio actual.
- `agent` — lanza el agente de IA de ESTE host (ver abajo).
- `zjssh <host>` — sesión dedicada a un host SSH; cada tab nuevo entra al host, sin anidar (ver abajo).

Con SSH y Zellij en ambos hosts: terminal local → shell plano; `zj` para Zellij local. `ssh mmja`
→ shell remoto plano → `zj` → Zellij remoto persistente, en la terminal actual y **sin anidar**.

### Agente por host (layout `dev`)

El primer tab del layout `dev` (el que abre `zjcwd`) corre `agent`, que resuelve **qué** agente de IA
lanzar en cada máquina — `claude` en casa, `codex` en el trabajo, etc. Un alias de shell no sirve aquí:
un pane de Zellij ejecuta el binario directo, sin pasar por tu `.zshrc`. Por eso `scripts/agent.sh` lo
resuelve por override **explícito** (sin autodetección), en este orden:

1. `$ZJ_AGENT` — ej. `export ZJ_AGENT=codex` en tu rc por-host.
2. `~/.config/zellij/agent.local` (1ª línea útil) — ej. `echo claude > ~/.config/zellij/agent.local`.
3. Si no defines ninguno, abre un shell con un aviso (el pane queda usable).

Acepta argumentos (`echo 'claude --resume' > ~/.config/zellij/agent.local`). `agent.local` está en
`.gitignore` (es por-host).

### Sesión por host SSH (`zjssh <host>`)

`zjssh mmja` abre (o entra a) una sesión **`ssh_mmja` dedicada al host**, donde **cada tab nuevo
entra solo por SSH** — no un shell local. Útil para trabajar en un remoto con varias tabs sin
teclear `ssh` cada vez. `exit` cierra el tab como un shell normal.

**Sin anidar (igual que `zjcwd`):** `zjssh` no arranca un cliente Zellij dentro de otro.
- **Dentro de Zellij** cambia de sesión con el plugin **zellij-switch** (como `zjcwd`). El plugin
  sólo pasa `--session`/`--layout` (no env ni `default_shell`), así que el SSH lo hornea el
  **layout `ssh`**: sus panes corren `scripts/ssh-host.sh`, que hace `exec ssh <host>`. Sin
  `$ZJ_SSH_HOST`, `ssh-host.sh` **deriva el host del nombre `ssh_<host>`** → usa un alias de
  `~/.ssh/config` (para `user@host`/`-A`, ponlo como `Host` en `~/.ssh/config`).
- **Fuera de Zellij** usa el CLI normal (`zellij attach -c`) con `$ZJ_SSH_HOST` (host exacto,
  permite `user@host`/`-A`) y `--default-shell scripts/ssh-host.sh`.

`ssh-host.sh` se auto-blinda: sólo hace SSH si la sesión se llama `ssh_<host>`; en cualquier otra
abre un shell local. El remoto **no** corre Zellij (aquí sólo el cliente) → shells remotos planos.

- **Splits de pane dentro de Zellij:** un split (`Alt-n`) es un shell **local**, no SSH —
  zellij-switch no puede fijar el `default_shell` de la sesión como sí hace el CLI de fuera. Para
  otro shell remoto abre un **tab** (`Alt-t`), que sí entra al host (vía `new_tab_template`).
- **Opciones por-host** (usuario, puerto, `-A` para reenviar el agente) → `~/.ssh/config`, no en `zjssh`.
- **Eficiencia:** N tabs = N conexiones. Para compartir una sola, en `~/.ssh/config`:
  ```
  Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 10m
  ```
- **Serialización:** el layout con que se creó la sesión queda "horneado"; para cambiarlo, borra la
  sesión (`zellij delete-session ssh_<host>`) o `./bootstrap.sh --clean`. Los panes con `command`
  del layout `ssh` pueden pedir confirmación al resucitar una sesión serializada (como el layout `dev`).

## Dependencias

`zellij` (0.44+), `curl`, `sed`, `cksum`, `hostname`, y `zsh` o `bash` (el shell del host). En macOS via Homebrew;
los plugins requieren Zellij ≥ 0.44.

## Piezas externas (NO viven en este repo)

Añádelas a mano en cada máquina:

- **Zellij opt-in (no auto-start)** — no hay arranque automático; entras con `zj` (ver arriba).
  En macOS, si Brew no está en PATH para shells no-interactivos, mete
  `eval "$(/opt/homebrew/bin/brew shellenv)"` en `~/.zshenv`.

- **SSH agent forwarding estable** — si entras con `ssh -A` a un host que corre Zellij, el
  socket del agente forwardeado cambia en cada conexión y Zellij persiste los paneles con el
  socket viejo (muerto) → "no hay llaves". Fíjalo a una ruta estable en `~/.config/sh/rc.sh`:
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

- **Ghostty `Shift+Enter`** — en `~/.config/ghostty/config`:
  ```ini
  keybind = shift+enter=text:\x1b\r
  ```
  Necesario para salto de línea en Claude Code/nvim (Zellij aplana el protocolo Kitty).

## Notas

- La barra muestra `[MODO] [🦀 host] [📁 sesión] [tabs]`. El **host** lleva color+emoji
  determinista por hash (mismo nombre → mismo look), vía `scripts/hostname-color.sh`. El nombre
  de **sesión** usa un estilo fijo (morado + 📁): zjstatus no puede pasar `{session}` a un
  command widget, así que su color no puede ser por-hash como el del host.
- **Cambiar de sesión:** `Alt-s` abre el session-manager (la "lista/dropdown" de sesiones), que se
  **navega y elige con el ratón**. `Alt-[` / `Alt-]` saltan directo a la sesión anterior/siguiente sin
  abrir nada, vía `scripts/session-cycle.sh` (calcula el destino y cambia con zellij-switch, sin anidar).
  Ojo: el nombre en la barra **no** es clickable — zjstatus sólo captura clics del ratón en las pestañas
  (`{tabs}`), no en `{session}`; por eso el disparador del selector es el teclado (`Alt-s`), no el clic.
- `config.kdl.verbose.bak` / `config.kdl.bak` son respaldos locales (ignorados por git).
