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
