# Serpiente

> **Targets Zymbol v0.0.8** — revised 2026-07-26

Classic Snake running in the terminal, written entirely in Zymbol.

Serpiente was the first real TUI program in the language — it served as a stress test
for the terminal primitives introduced in **Zymbol v0.0.5**, and was retrofitted with
full internationalization in **v0.0.8**.

> **Validation project for Zymbol v0.0.5** — built to stress-test TUI primitives, the
> register VM, hot-definition variables, and the standalone packaging pipeline.
>
> **Revisited for v0.0.8** — the game is now bilingual (Spanish / English) and every
> panel is built from measured content via `std/term` instead of fixed-width literals.
> See [AUDITORIA_I18N_ES.md](AUDITORIA_I18N_ES.md) and the project-wide doctrine in
> [USERAPPI18N.md](https://github.com/zymbol-lang/interpreter/blob/main/USERAPPI18N.md).

> **Español:** [README_ES.md](README_ES.md)

---

## How to play

```bash
zymbol run serpiente.zy    # Spanish
zymbol run snake.zy        # English
```

Requires the Zymbol interpreter **v0.0.8 or later** (the layout depends on `std/term`)
and a terminal of at least 34 × 14 characters. The game detects the real terminal size
at startup and adapts the board automatically.

The two entry points differ only in the language the first screen comes up in.

---

## Controls

| Key | Action |
|-----|--------|
| `W` / `↑` | Move up |
| `S` / `↓` | Move down |
| `A` / `←` | Move left |
| `D` / `→` | Move right |
| `P` | Pause / resume |
| `Q` | Quit during a game |

---

## Screens

### Speed selection

A centered menu appears at startup. Navigate with `↑` `↓` and confirm with `↵`
(you can also press `1`–`5` directly):

```
╭───────────────────────────────╮
│         Z Y M B O L           │
│          S N A K E            │
├───────────────────────────────┤
│   Choose your speed:          │
│                               │
│   ► [1]  Slow        160 ms   │
│     [2]  Normal      130 ms   │
│     [3]  Fast        100 ms   │
│     [4]  Infernal    70 ms    │
│     [5]  Insane      40 ms    │
╰───────────────────────────────╯
```

The frame is not typed: the labels come from the active locale and the box is built
around the widest of them, so the Spanish menu is a different width and still squares
up. The `►` marker is added *before* measuring, which is why the rows do not shift
when the cursor moves.

### Gameplay

The board fills the entire terminal. The snake is drawn as a tube with rounded corners
(`─ │ ╭ ╮ ╰ ╯`) and the head points in the direction of movement (`▶ ▲ ◀ ▼`).
When food is eaten, an `@` mark appears at the food's position and disappears naturally
once the snake's tail reaches that cell. The score counter overlays the top border.

```
╭─────────┤ ✦ SCORE 3 ✦ ├──────────────╮
│                                        │
│            🍓                          │
│                                        │
│      ╭──╮                             │
│      ╰──▶@               🍎           │
│                                        │
╰────────────────────────────────────────╯
```

**Available fruits:** 🍎 🍊 🍋 🍇 🍓 🫐 🍑 🥝 🍒 🍉 — one is chosen at random
on each spawn. Each fruit occupies 2 columns; spawn position avoids the right border
to prevent overflow.

### Pause

Press `P` during a game to show a centered pause panel. Press `P` again to resume.

### Game Over

When the snake hits a wall or its own body, a centered menu appears.
Navigate with `↑` `↓` + `↵` (or press `N` / `S` / `A` directly):

```
╭────────────────────────────────╮
│            G A M E             │
│            O V E R             │
├────────────────────────────────┤
│   Score: 7    Best: 12         │
│   Game 3 of this session       │
│                                │
│   ► New game                   │
│     Quit                       │
│     Help                       │
╰────────────────────────────────╯
```

- **New game** — restart with the same speed chosen at startup
- **Quit** — exit and restore the terminal
- **Help** — show full controls; any key returns to the menu

---

## Architecture

```
serpiente/
├── serpiente.zy    entry point — preselects Spanish
├── snake.zy        entry point — preselects English
├── juego.zy        the game: seed, dimensions, @:main and @:game loops
├── logica.zy       movement, collisions, food spawn, and LCG
├── dibujo.zy       all output: menus, board, delta rendering, pause, game over
├── marco.zy        panels built from measured content — no fixed widths
├── texto.zy        Spanish layer over std/term (column metrics)
├── idioma/
│   ├── despacho.zy i18n dispatcher — holds the locale as module state
│   ├── español.zy  Spanish locale (base language, where the keys come from)
│   └── english.zy  English locale
├── pruebas/
│   ├── verificación_idioma.zy  completeness gate: keys × locales, frames, badge
│   └── todas.sh                runs every suite in both engines
├── AUDITORIA_I18N_ES.md  i18n audit of the project (Spanish)
└── HALLAZGOS_ES.md       bug/gap/idea registry found during development (Spanish)
```

### Modules

**`logica.zy`** exports:
- `lcg_sig(semilla)` — advance the LCG seed one step (Numerical Recipes)
- `rango_aleatorio(semilla, min, max)` — integer in `[min, max]`; returns `(value, next_seed)`
- `fruta_aleatoria(semilla)` — random fruit emoji; returns `(emoji, next_seed)`
- `nueva_dir(tecla, dir)` — map key to direction; prevents instant reversal
- `nueva_comida(serpiente, AN, AL, semilla)` — spawn position `(row, col)` not overlapping the snake; returns `(pos, next_seed)`
- `tick_comida(comio, serpiente, AN, AL, semilla, comida, fruta)` — generate new food and fruit if `comio=#1`; returns `(food, fruit, seed)` unchanged otherwise
- `mover(serpiente, dir, comida, puntos, AN, AL)` — advance one tick; returns `(alive, snake, points, ate, head_pos)`

**`dibujo.zy`** exports:
- `menu_velocidad(AN, AL)` — speed menu with `↑↓ + ↵`; returns delay in ms
- `dibujar_inicio(serpiente, comida, fruta, puntos, AN, AL)` — full initial frame
- `dibujar(serpiente, cola_vieja, comio, comida_vieja, comida, fruta, puntos, AN, AL)` — delta rendering
- `fin_juego(puntos, AN, AL)` — game-over overlay + menu; returns `'n'` (new) or `'s'` (quit)
- `pausa(AN, AL)` — draw pause panel; blocks until `P` is pressed again

### Delta rendering

`dibujar` does not clear the screen on every tick. Only changed cells are updated:

| Event | Updated cells |
|-------|---------------|
| Normal movement | new head, previous head → body, erase old tail, redraw new tail |
| Food eaten | erase emoji (2 cols), draw `@` at food pos, old head → body, draw new food |
| Subsequent ticks | `@` cell untouched — remains visible while it is a body segment |
| Tail reaches `@` | normal tail cleanup erases `@` automatically |

### Randomness

The initial seed is derived from three independent entropy sources via BashExec
(`date +%N`, `$$`, `/dev/urandom`). From there, all randomness uses an LCG
implemented in pure Zymbol — no BashExec per tick, no subprocess latency.

---

## Zymbol v0.0.5 primitives used

| Primitive | Use in Serpiente |
|-----------|-----------------|
| `>>| { }` | TUI block — alternate screen, raw mode, hidden cursor |
| `>>~ (r, c, fg) > items` | Positioned output with ANSI 256 color |
| `>>!` | Clear screen (startup, menus, pause) |
| `>>?` | Query real terminal size at startup |
| `<<\| var` | Blocking key read (menus, pause, game over) |
| `<<\|? var` | Non-blocking key read (game loop) |
| `@~ ms` | Sleep in milliseconds (game speed) |

---

## Language findings

During the development of Serpiente, fixed bugs, missing capabilities, and improvement
ideas were documented in [`HALLAZGOS_ES.md`](HALLAZGOS_ES.md) (Spanish).

Quick summary:

| Type | Total | Status |
|------|-------|--------|
| BUG  | 4 | 3 fixed in v0.0.5 · 1 with workaround |
| GAP  | 6 | open (workarounds in use where applicable) |
| IDEA | 1 | proposed |
