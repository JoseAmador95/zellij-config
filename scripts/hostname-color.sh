#!/bin/sh
# Emite el hostname corto como "pastilla" coloreada (con emoji) para zjstatus.
# Color Y emoji se eligen de forma DETERMINISTA a partir de un checksum del
# hostname: mismo hostname → mismo color+emoji siempre (no random, no hardcodeado).
# Se usa con: command_..._rendermode "dynamic"  (zjstatus interpreta los #[...]).

h=$(hostname -s 2>/dev/null || hostname)

# checksum estable del string → índice 0..7
i=$(printf '%s' "$h" | cksum | cut -d' ' -f1)
i=$((i % 8))

# 8 colores muy visibles (fg con contraste) + 8 emojis distintos, mismo índice
case "$i" in
  0) bg="#E53935"; fg="#FFFFFF"; emo="🦀" ;;  # rojo
  1) bg="#FB8C00"; fg="#000000"; emo="🚀" ;;  # naranja
  2) bg="#FDD835"; fg="#000000"; emo="🐳" ;;  # amarillo
  3) bg="#43A047"; fg="#FFFFFF"; emo="🌵" ;;  # verde
  4) bg="#00ACC1"; fg="#000000"; emo="🐙" ;;  # cyan
  5) bg="#1E88E5"; fg="#FFFFFF"; emo="🦊" ;;  # azul
  6) bg="#8E24AA"; fg="#FFFFFF"; emo="🍄" ;;  # morado
  7) bg="#EC407A"; fg="#FFFFFF"; emo="🦉" ;;  # rosa
esac

# Padding con espacios dentro del bg → pastilla visible; emoji a la izquierda
printf '#[bg=%s,fg=%s,bold]  %s %s  #[default]' "$bg" "$fg" "$emo" "$h"
