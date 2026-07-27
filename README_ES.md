# Serpiente

> **Apunta a Zymbol v0.0.8** — revisado el 2026-07-26

Snake clásico corriendo en la terminal, escrito completamente en Zymbol.

Serpiente fue el primer programa TUI real en el lenguaje — sirvió como prueba de fuego
de las primitivas de terminal introducidas en **Zymbol v0.0.5**, y en **v0.0.8** se le
añadió internacionalización completa.

> **Proyecto de validación de Zymbol v0.0.5** — construido para poner a prueba las
> primitivas TUI, la VM de registros, las variables hot-definition y el pipeline de
> empaquetado standalone.
>
> **Revisitado para v0.0.8** — el juego es ahora bilingüe (español / inglés) y cada
> panel se construye midiendo su contenido con `std/term` en vez de con literales de
> ancho fijo. Ver [AUDITORIA_I18N_ES.md](AUDITORIA_I18N_ES.md) y la doctrina común en
> [USERAPPI18N.md](https://github.com/zymbol-lang/interpreter/blob/main/USERAPPI18N.md).

> **English:** [README.md](README.md)

---

## Cómo jugar

```bash
zymbol run serpiente.zy    # español
zymbol run snake.zy        # inglés
```

Requiere el intérprete de Zymbol **v0.0.8 o posterior** (la maquetación depende de
`std/term`) y una terminal de al menos 34 × 14 caracteres. El juego detecta el tamaño
real al arrancar y adapta el tablero automáticamente.

Los dos puntos de entrada solo se diferencian en el idioma con el que arranca la
primera pantalla. En cualquiera de los dos, `L` cambia de idioma desde dentro del
juego: los puntos de entrada son una comodidad, no el único camino.

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
| `L` | Cambiar de idioma — en las pantallas de inicio y de fin de partida |

---

## Pantallas

### Selección de velocidad

Al iniciar aparece un menú centrado. Se navega con `↑` `↓` y se confirma con `↵`
(también se puede pulsar directamente `1`–`5`):

```
╭───────────────────────────────╮
│         Z Y M B O L           │
│      S E R P I E N T E        │
├───────────────────────────────┤
│   Elige tu velocidad:         │
│                               │
│   ► [1]  Lento       160 ms   │
│     [2]  Normal      130 ms   │
│     [3]  Rápido      100 ms   │
│     [4]  Infernal    70 ms    │
│     [5]  Demencial   40 ms    │
╰───────────────────────────────╯
```

El marco no está tecleado: las etiquetas vienen del idioma activo y la caja se
construye alrededor de la más ancha, así que el menú en inglés tiene otro ancho y
también cuadra. La marca `►` se añade *antes* de medir, y por eso las filas no se
mueven de sitio al mover el cursor.

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
╭──────────────────────────────────╮
│            J U E G O             │
│          T E R M I N Ó           │
├──────────────────────────────────┤
│   Puntaje: 7    Récord: 12       │
│   Partida 3 de la sesión         │
│                                  │
│   ► Nuevo juego                  │
│     Salir                        │
│     Ayuda                        │
╰──────────────────────────────────╯
```

- **Nuevo juego** — reinicia la partida (misma velocidad elegida al inicio)
- **Salir** — cierra el juego y restaura el terminal
- **Ayuda** — muestra los controles completos; vuelve al menú al presionar cualquier tecla

---

## Arquitectura

```
serpiente/
├── serpiente.zy    punto de entrada — preselecciona español
├── snake.zy        punto de entrada — preselecciona inglés
├── juego.zy        el juego: semilla, dimensiones, loop @:main y @:game
├── logica.zy       movimiento, colisiones, spawn de comida y LCG
├── dibujo.zy       todo el output: menús, tablero, delta rendering, pausa, game over
├── marco.zy        paneles construidos midiendo el contenido — sin anchos fijos
├── texto.zy        capa en español sobre std/term (medidas de columna)
├── idioma/
│   ├── despacho.zy despachador de i18n — guarda el idioma como estado de módulo
│   ├── español.zy  idioma español (base: de aquí salen las claves)
│   └── english.zy  idioma inglés
├── pruebas/
│   ├── verificación_idioma.zy  puerta de completitud: claves × idiomas, marcos, marcador
│   └── todas.sh                corre todas las suites en los dos motores
├── AUDITORIA_I18N_ES.md  auditoría de i18n del proyecto
└── HALLAZGOS_ES.md       registro de bugs, gaps e ideas encontrados durante la construcción
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
