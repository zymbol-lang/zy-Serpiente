# Serpiente

Snake clásico corriendo en la terminal, escrito completamente en Zymbol.

Serpiente fue el primer programa TUI real en el lenguaje — sirvió como prueba de fuego
de las primitivas de terminal introducidas en **Zymbol v0.0.5**.

> **English:** [README.md](README.md)

---

## Cómo jugar

```bash
zymbol run serpiente.zy
```

Requiere una terminal de al menos 34 × 14 caracteres. El juego detecta el tamaño real
al arrancar y adapta el tablero automáticamente.

---

## Controles

| Tecla | Acción |
|-------|--------|
| `W` / `↑` | Mover arriba |
| `S` / `↓` | Mover abajo |
| `A` / `←` | Mover izquierda |
| `D` / `→` | Mover derecha |
| `P` | Pausar / continuar |
| `Q` | Salir durante la partida |

---

## Pantallas

### Selección de velocidad

Al iniciar aparece un menú centrado. Se navega con `↑` `↓` y se confirma con `↵`
(también se puede pulsar directamente `1`–`5`):

```
╭──────────────────────────────╮
│        Z Y M B O L          │
│      S E R P I E N T E      │
├──────────────────────────────┤
│   Elige tu velocidad:        │
│                              │
│ ► [1]  Lento      160 ms    │
│   [2]  Normal     130 ms    │
│   [3]  Rápido     100 ms    │
│   [4]  Infernal    70 ms    │
│   [5]  Demencial   40 ms    │
╰──────────────────────────────╯
```

### Juego

El tablero ocupa toda la terminal. La serpiente se dibuja como un tubo con esquinas
redondeadas (`─ │ ╭ ╮ ╰ ╯`) y la cabeza apunta en la dirección de movimiento (`▶ ▲ ◀ ▼`).
Al comer, aparece un `@` en la posición de la fruta que desaparece cuando la cola
de la serpiente lo alcanza. El marcador de puntos se superpone sobre el borde superior.

```
╭─────────┤ ✦ PUNTOS 3 ✦ ├──────────────╮
│                                        │
│            🍓                          │
│                                        │
│      ╭──╮                             │
│      ╰──▶@               🍎           │
│                                        │
╰────────────────────────────────────────╯
```

**Frutas disponibles:** 🍎 🍊 🍋 🍇 🍓 🫐 🍑 🥝 🍒 🍉 — se escoge una al azar
en cada spawn. Cada fruta ocupa 2 columnas; la posición de spawn evita el borde derecho
del tablero para que nunca desborde el marco.

### Pausa

Al pulsar `P` durante la partida aparece un panel centrado. El juego se reanuda
pulsando `P` de nuevo.

### Game Over

Al colisionar con una pared o con el propio cuerpo aparece un menú centrado.
Se navega con `↑` `↓` + `↵` (o con las letras `N` / `S` / `A`):

```
╭───────────────────╮
│     J U E G O     │
│   T E R M I N Ó   │
╰───────────────────╯

Puntaje final: 7

► Nuevo juego
  Salir
  Ayuda
```

- **Nuevo juego** — reinicia la partida (misma velocidad elegida al inicio)
- **Salir** — cierra el juego y restaura el terminal
- **Ayuda** — muestra los controles completos; vuelve al menú al presionar cualquier tecla

---

## Arquitectura

```
serpiente/
├── serpiente.zy    entry point — semilla, dimensiones, loop @:main y @:game
├── logica.zy       movimiento, colisiones, spawn de comida y LCG
├── dibujo.zy       todo el output: menús, tablero, delta rendering, pausa, game over
└── HALLAZGOS_ES.md registro de bugs, gaps e ideas encontrados durante la construcción
```

### Módulos

**`logica.zy`** exporta:
- `lcg_sig(semilla)` — avanza la semilla LCG un paso (Numerical Recipes)
- `rango_aleatorio(semilla, min, max)` — entero en `[min, max]`; retorna `(valor, semilla_sig)`
- `fruta_aleatoria(semilla)` — emoji de fruta al azar; retorna `(emoji, semilla_sig)`
- `nueva_dir(tecla, dir)` — mapea tecla a dirección; bloquea reversión instantánea
- `nueva_comida(serpiente, AN, AL, semilla)` — posición `(fila, col)` sin colisionar con la serpiente; retorna `(pos, semilla_sig)`
- `tick_comida(comio, serpiente, AN, AL, semilla, comida, fruta)` — genera nueva comida y fruta si `comio=#1`; retorna `(comida, fruta, semilla)` sin cambios si no se comió
- `mover(serpiente, dir, comida, puntos, AN, AL)` — avanza un tick; retorna `(vivo, serpiente, puntos, comio, cab)`

**`dibujo.zy`** exporta:
- `menu_velocidad(AN, AL)` — menú con `↑↓ + ↵`; retorna delay en ms
- `dibujar_inicio(serpiente, comida, fruta, puntos, AN, AL)` — frame completo inicial
- `dibujar(serpiente, cola_vieja, comio, comida_vieja, comida, fruta, puntos, AN, AL)` — delta rendering
- `fin_juego(puntos, AN, AL)` — overlay + menú post-partida; retorna `'n'` (nueva) o `'s'` (salir)
- `pausa(AN, AL)` — dibuja panel de pausa; bloquea hasta que se vuelva a pulsar `P`

### Delta rendering

`dibujar` no borra la pantalla en cada tick. Solo actualiza las celdas que cambiaron:

| Evento | Celdas actualizadas |
|--------|---------------------|
| Movimiento normal | nueva cabeza, cabeza anterior → cuerpo, borra cola vieja, redibuja nueva cola |
| Comida ingerida | borra emoji (2 cols), dibuja `@` en posición comida, vieja cabeza → cuerpo, dibuja nueva comida |
| Tick posterior a comer | celda `@` sin cambio — permanece visible mientras sea un segmento del cuerpo |
| Cola alcanza `@` | limpieza normal de cola borra el `@` automáticamente |

### Aleatoriedad

La semilla inicial se deriva de tres fuentes de entropía independientes via BashExec
(`date +%N`, `$$`, `/dev/urandom`). A partir de ahí toda la aleatoriedad usa un LCG
implementado en Zymbol puro — sin BashExec por tick, sin latencia de subproceso.

---

## Primitivas de Zymbol v0.0.5 utilizadas

| Primitiva | Uso en Serpiente |
|-----------|-----------------|
| `>>| { }` | Bloque TUI — alternate screen, raw mode, cursor oculto |
| `>>~ (r, c, fg) > items` | Output posicionado con color ANSI 256 |
| `>>!` | Limpiar pantalla (inicio, menús, pausa) |
| `>>?` | Consultar tamaño real del terminal al arrancar |
| `<<\| var` | Lectura bloqueante de tecla (menús, pausa, game over) |
| `<<\|? var` | Lectura no bloqueante de tecla (game loop) |
| `@~ ms` | Pausa en milisegundos (velocidad de juego) |

---

## Hallazgos del lenguaje

Durante la construcción de Serpiente se documentaron bugs corregidos, capacidades ausentes
e ideas de mejora en [`HALLAZGOS_ES.md`](HALLAZGOS_ES.md).

Resumen rápido:

| Tipo | Total | Estado |
|------|-------|--------|
| BUG  | 4 | 3 resueltos en v0.0.5 · 1 con workaround |
| GAP  | 6 | abiertos (workarounds en uso donde aplica) |
| IDEA | 1 | propuesta |
