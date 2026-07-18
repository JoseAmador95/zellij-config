#!/bin/sh
# Emite el NOMBRE DE SESIÓN como pastilla coloreada (con emoji) para zjstatus.
# Color+emoji deterministas por nombre de sesión (mismo nombre → mismo look).
# La sesión se toma de $ZELLIJ_SESSION_NAME (Zellij la expone por sesión);
# fallback a $1 si algún día se pasa como argumento. Usar con rendermode "dynamic".

s="${ZELLIJ_SESSION_NAME:-}"
[ -z "$s" ] && s="$1"
[ -z "$s" ] && s="?"

# checksum estable → índice 0..7
i=$(printf '%s' "$s" | cksum | cut -d' ' -f1)
i=$((i % 8))

# misma paleta de 8 colores que el hostname, pero SET DE EMOJIS distinto
# (así la pastilla de sesión se distingue de la de host de un vistazo)
case "$i" in
  0) bg="#E53935"; fg="#FFFFFF"; emo="📁" ;;  # rojo
  1) bg="#FB8C00"; fg="#000000"; emo="🎯" ;;  # naranja
  2) bg="#FDD835"; fg="#000000"; emo="🌟" ;;  # amarillo
  3) bg="#43A047"; fg="#FFFFFF"; emo="🎨" ;;  # verde
  4) bg="#00ACC1"; fg="#000000"; emo="🧩" ;;  # cyan
  5) bg="#1E88E5"; fg="#FFFFFF"; emo="🎸" ;;  # azul
  6) bg="#8E24AA"; fg="#FFFFFF"; emo="🎲" ;;  # morado
  7) bg="#EC407A"; fg="#FFFFFF"; emo="🔮" ;;  # rosa
esac

printf '#[bg=%s,fg=%s,bold]  %s %s  #[default]' "$bg" "$fg" "$emo" "$s"
