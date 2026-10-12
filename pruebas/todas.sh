#!/usr/bin/env bash
# ============================================================
# pruebas/todas.sh — todas las suites de Serpiente
#
#   bash pruebas/todas.sh
#
# El juego en sí no se puede probar aquí: >>| se niega a arrancar
# sin una terminal de verdad, así que el bucle de partida y las
# cuatro pantallas se prueban a mano. Lo que sí es automatizable
# —el catálogo de idiomas, las frases compuestas y el cuadre de los
# marcos— corre en los dos motores.
#
# EN: pruebas/todas.sh — every Serpiente suite. The game itself
# cannot be tested here (>>| refuses to start without a real
# terminal), but the i18n catalogue, the composed messages and the
# frame arithmetic are, in both engines.
# ============================================================
#
# ── NOTE ─────────────────────────────────────────────────────────────────
# This script is not the authority. It used to decide correctness by
# grepping the suite's output for FALLA, so a suite that crashed half way
# through printed no FALLA and passed — measured, not supposed. Since
# 2026-09-29 each suite ends a failing run with `<~ 1` (IDEA-GOL-012), and
# a crash exits non-zero anyway, so this reads the exit status instead.
# It still runs two engines of the three.
#
# The gate is in ZyQuality, which compares each suite against a golden (a
# truncated run does not match one) and runs every engine that can:
#
#     cd ../zyquality && ./zyq suite --only project
#     cd ../zyquality && bash project/run.sh --only serpiente
#
# What is still worth running here is the `zymbol check` sweep below, which
# is about this application's own sources.
# ─────────────────────────────────────────────────────────────────────────
set -u
cd "$(dirname "$0")/.."

fallo=0

for motor in "" "--vm"; do
    for suite in pruebas/verificación_idioma.zy pruebas/verificación_lógica.zy; do
        etiqueta="$suite ${motor:-tree-walker}"
        echo "─── $etiqueta"
        salida=$(zymbol run $motor "$suite" 2>&1)
        estado=$?
        echo "$salida" | tail -1
        if [ "$estado" -ne 0 ]; then
            echo "$salida"
            fallo=1
        fi
        echo
    done
done

echo "─── zymbol check"
for archivo in serpiente.zy snake.zy juego.zy dibujo.zy logica.zy marco.zy texto.zy \
               idioma/despacho.zy idioma/español.zy idioma/english.zy; do
    if salida=$(zymbol check "$archivo" 2>&1); then
        echo "  OK     $archivo"
    else
        echo "  FALLA  $archivo"
        echo "$salida"
        fallo=1
    fi
done
echo

if [ "$fallo" -eq 0 ]; then
    echo "todas PASA"
else
    echo "todas FALLA"
    exit 1
fi
