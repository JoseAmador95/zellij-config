#!/bin/sh
# session-list.sh — imprime las sesiones VIVAS, una por línea, en el orden canónico.
#
# Es la FUENTE ÚNICA del orden: el salto por índice
# (session-goto.sh) y el ciclo anterior/siguiente (session-cycle.sh) leen de aquí. Por eso
# "la sesión 2" es la misma en ambos, y Alt-. avanza justo al índice siguiente.
#
# Orden alfabético (sort -u): `zellij list-sessions` no garantiza ninguno, y un orden estable
# es lo que hace predecible el ciclo y reutilizable el índice.
#
# Formato de cada línea de list-sessions: "<nombre> [Created …]" y, según el caso,
# " (current)" o " (EXITED - attach to resurrect)". Nos quedamos con el primer token de las
# que no están EXITED.
set -u

zellij list-sessions --no-formatting 2>/dev/null | grep -v 'EXITED' | awk 'NF{print $1}' | sort -u
