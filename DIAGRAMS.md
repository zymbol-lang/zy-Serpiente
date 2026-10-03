# Serpiente — diagrams

A first look at which UML views fit a Zymbol program. Zymbol has no
classes, so there is no class diagram here; what it has instead is
modules with state and an export list, labelled loops, and functions
that hand state back through tuples. Each diagram below is chosen to
show one of those.

Identifiers in the diagrams are the program's own (Spanish); Mermaid
node ids are ASCII with the real name as the label, because accented
ids break Mermaid's parser.

| # | View | UML diagram | What it shows about Zymbol |
|---|------|-------------|----------------------------|
| 1 | Modules | component (drawn as `classDiagram`) | `# módulo`, `#>` exports, `<#` imports with alias, module state |
| 2 | Screens | state machine | labelled loops `@:main`, `@:game` and their `>` / `!` exits |
| 3 | One tick | sequence | state threaded through return tuples, terminal I/O |
| 4 | `l::mover` | activity | the one function whose logic earns a picture |
| 5 | Game state | object | the shape of the data and who produces each field |

---

## 1. Modules

A module is drawn as a class with the `<<module>>` stereotype:
attributes are module state and constants, `+` is exported through `#>`,
`-` is a `_private` function. Arrows are `<#` imports, labelled with the
alias. The locale contract is an interface nobody declares: `español.zy`
and `english.zy` satisfy it by exporting the same three names, and
`despacho` is the only module that knows both exist.

```mermaid
classDiagram
    direction TB

    class serpiente_zy["serpiente.zy"] {
        <<script>>
        juego::iniciar("es")
    }
    class snake_zy["snake.zy"] {
        <<script>>
        juego::iniciar("en")
    }

    class juego {
        <<module>>
        +iniciar(código)
    }

    class logica {
        <<module>>
        +lcg_sig(semilla)
        +rango_aleatorio(semilla, min, max)
        +fruta_aleatoria(semilla)
        +nueva_comida(serpiente, AN, AL, semilla)
        +tick_comida(comio, serpiente, AN, AL, semilla, comida, fruta)
        +nueva_dir(tecla, dir)
        +mover(serpiente, dir, comida, puntos, AN, AL, crecer)
        -_en_serpiente(serpiente, pos)
    }

    class dibujo {
        <<module>>
        BORDE, VERDE, CABEZA, COMIDA, ROJO, TEXTO
        +menu_velocidad(AN, AL) retardo
        +dibujar_inicio(serpiente, comida, fruta, puntos, AN, AL)
        +dibujar(serpiente, cola_vieja, crecer, comio, ...)
        +pausa(AN, AL)
        +fin_juego(puntos, partidas, marcadores, AN, AL) accion
        -_ayuda(AN, AL)
        -_marcador(puntos, AN)
        -_pintar(filas, colores, fila0, col0)
        -_esquina(filas, AN, AL)
        -_mover_sel(tecla, sel, max)
        -_char_cabeza(cab, cuerpo)
        -_char_cuerpo(ant, pos, sig)
        -_char_cola(penultimo, cola)
    }

    class marco {
        <<module>>
        +SEPARADOR
        +CENTRADO
        +construir(líneas, hueco)
        +ancho_de(líneas)
        +fila_menú(número, etiqueta, seleccionada)
        -_desnudo(l)
    }

    class texto {
        <<module>>
        +ancho      = t::width
        +izquierda  = t::pad_left
        +derecha    = t::pad_right
        +centrar    = t::center
        +recortar   = t::truncate
    }

    class std_term["std/term"] {
        <<std>>
        width, pad_left, pad_right, center, truncate
    }

    class despacho["idioma/despacho"] {
        <<module>>
        -idioma_actual = "es"
        +fijar(código)
        +actual()
        +rotar()
        +idiomas()
        +claves()
        +texto(clave)
        +marcador(puntos)
        +texto_partida(n)
        -_siguiente()
    }

    class Contrato["locale contract"] {
        <<interface>>
        +texto(clave)
        +marcador(puntos)
        +texto_partida(n)
    }

    class es["idioma/español"] {
        <<module>>
    }
    class en["idioma/english"] {
        <<module>>
    }

    class prueba_idioma["pruebas/verificación_idioma"] {
        <<test>>
    }
    class prueba_logica["pruebas/verificación_lógica"] {
        <<test>>
    }

    serpiente_zy ..> juego : juego
    snake_zy ..> juego : juego

    juego ..> logica : l
    juego ..> dibujo : d
    juego ..> despacho : idioma

    dibujo ..> despacho : idioma
    dibujo ..> texto : txt
    dibujo ..> marco : marco
    marco ..> texto : txt
    texto ..> std_term : t

    despacho ..> es : es
    despacho ..> en : en
    es ..|> Contrato
    en ..|> Contrato

    prueba_idioma ..> despacho : idioma
    prueba_idioma ..> texto : txt
    prueba_idioma ..> marco : marco
    prueba_logica ..> logica : l
```

What the picture makes visible:

- `logica` imports nothing and draws nothing; `dibujo` returns nothing
  except the two menu choices. The split between computing and drawing
  is a line in the graph, not a convention in a comment.
- `idioma_actual` is the only module state in the program. No drawing
  function takes a language parameter because of it.
- `texto` exports nothing of its own: it is a Spanish re-export layer
  over `std/term` (the code-i18n mechanism of `I18N.md`).
- `logica` has a test and `dibujo` does not; `juego` has neither.

---

## 2. Screens

The labelled loops are the states. `@:main>` is *continue* (a fresh
game), `@:game!` and `@:main!` are *break*. Everything runs inside
`>>| { … }`, the TUI mode.

```mermaid
stateDiagram-v2
    direction TB

    [*] --> Arranque
    Arranque : Arranque
    Arranque : idioma fijar(código)
    Arranque : size from terminal query
    Arranque : seed from three shell calls

    Arranque --> TUI

    state TUI {
        [*] --> Velocidad

        state "Speed menu  @:sel" as Velocidad
        Velocidad --> Velocidad : L  rotar()
        Velocidad --> Velocidad : up / down  move cursor
        Velocidad --> Main : 1-5 or Enter  gives retardo

        state "@:main" as Main {
            [*] --> Preparar
            state "New game" as Preparar
            Preparar : snake of 3 at centre, dir right
            Preparar : nueva_comida, fruta_aleatoria
            Preparar : dibujar_inicio

            state "@:game  (one tick every retardo ms)" as Game
            Preparar --> Game

            state "Pause  @:espera" as Pausa
            Game --> Pausa : P
            Pausa --> Game : P  then dibujar_inicio

            Game --> Preparar : terminal resized  @:main>

            Game --> FinJuego : Q  @:game!
            Game --> FinJuego : dead  @:game!

            state "Game over  @:menu" as FinJuego
            FinJuego : partidas += 1, marcadores + puntos
            state "Help" as Ayuda
            FinJuego --> Ayuda : A
            Ayuda --> FinJuego : any key
            FinJuego --> FinJuego : L  rotar()
            FinJuego --> Preparar : N  new game
        }

        Main --> [*] : S  @:main!
    }

    TUI --> [*]
```

Two things a reader would otherwise have to find in the code:

- A resize goes back through `@:main>` **without** passing through game
  over, so it does not count as a game played.
- The language can change in two states only (speed menu, game over),
  never mid-game, and a change needs no state of its own: it rewrites
  the module state and the loop redraws.

---

## 3. One tick

What `@:game` does on each pass. Return arrows carry the tuple the
caller destructures: nothing a function receives is changed in place,
so every piece of state that moves is visible on an arrow.

```mermaid
sequenceDiagram
    autonumber
    actor T as Terminal
    participant J as juego
    participant L as l (logica)
    participant D as d (dibujo)
    participant I as idioma (despacho)
    participant X as txt (texto)

    J->>T: <<|? tecla  (non-blocking)
    T-->>J: key, or '\0'
    J->>T: >>?  (filas, cols)
    T-->>J: current size

    alt size changed
        J-->>J: @:main>  (new game, centred)
    else Q
        J-->>J: @:game!
    else P
        J->>D: pausa(AN, AL)
        D->>T: <<| until P
        J->>D: dibujar_inicio(...)
    end

    opt tecla is not '\0'
        J->>L: nueva_dir(tecla, dir)
        L-->>J: dir  (reversal refused)
    end

    J->>L: mover(serpiente, dir, comida, puntos, AN, AL, crecer)
    L-->>J: (vivo, serpiente, puntos, comio)

    J->>L: tick_comida(comio, serpiente, AN, AL, semilla, comida, fruta)
    opt comio
        L->>L: nueva_comida then fruta_aleatoria  (seed advances twice)
    end
    L-->>J: (comida, fruta, semilla)

    J-->>J: pos_arroba = pendiente, update pendiente

    alt not vivo
        J-->>J: @:game!
    else alive
        J->>D: dibujar(serpiente, cola_vieja, crecer, comio, comida_vieja, comida, fruta, puntos, AN, AL, pos_arroba)
        D->>T: >>~ only the cells that changed
        D->>I: marcador(puntos)
        I-->>D: badge in the active locale
        D->>X: ancho(badge)
        X-->>D: columns
        D->>T: >>~ badge centred on top border
        J-->>J: @~ retardo
    end
```

`semilla` is the clearest case: `logica` keeps no hidden generator, so
the seed goes out and comes back on every call that draws a random
number. The same holds for the snake itself.

---

## 4. `l::mover`

The collision rules, including the deferred growth: the tail stays on
the tick **after** eating, which is why `crecer` changes how far the
self-collision check reaches.

```mermaid
flowchart TD
    A([mover]) --> B["cab = head moved one step in dir"]
    B --> C{"outside the walls?<br/>rows 2..AL+1, cols 2..AN+1"}
    C -- yes --> DEAD(["return (false, serpiente, puntos, false)"])
    C -- no --> E["comio = cab is on comida<br/>(either column of the wide emoji)"]
    E --> F{"crecer?"}
    F -- yes --> G["limite = length<br/>tail stays, so it counts"]
    F -- no --> H["limite = length - 1<br/>tail leaves this tick"]
    G --> I{"cab hits segment 1..limite?"}
    H --> I
    I -- yes --> DEAD
    I -- no --> J["serpiente = serpiente $+[1] cab"]
    J --> K{"comio?"}
    K -- yes --> K2["puntos + 1"] --> M
    K -- no --> M{"crecer?"}
    M -- no --> N["serpiente = serpiente $-[-1]<br/>drop tail"]
    M -- yes --> OK
    N --> OK(["return (true, serpiente, puntos, comio)"])
```

`false` / `true` stand for `#0` / `#1`, which Mermaid reads as the
start of an entity code.

---

## 5. Game state

The locals of `juego::iniciar`, grouped by lifetime, with the function
that produces each one. There are no records in the program: these are
plain variables, and the shapes are tuples and arrays. Tuples are
written `⟨fila, col⟩` because Mermaid reads parentheses as a method.

```mermaid
classDiagram
    direction LR

    class Sesion["session  (whole run)"] {
        AN, AL : Int  board interior, from terminal query
        retardo : Int  ms, from d::menu_velocidad
        semilla : Int  LCG seed, from shell, threaded through l::
        °partidas : Int  games played
        °marcadores : [Int]  score per game
    }

    class Partida["game  (one @:main pass)"] {
        serpiente : [⟨fila, col⟩]  index 1 is the head
        dir : Char  one of the four arrows
        puntos : Int
        comida : ⟨fila, col⟩
        fruta : String  emoji
        pendiente : ⟨fila, col⟩ or false  where to show @ next tick
    }

    class Tick["tick  (one @:game pass)"] {
        tecla : Char  '\0' when no key
        cola_vieja : ⟨fila, col⟩
        comida_vieja : ⟨fila, col⟩
        crecer : Bool  pendiente is set
        vivo : Bool
        comio : Bool
        pos_arroba : ⟨fila, col⟩ or false
    }

    Sesion *-- Partida : one per game
    Partida *-- Tick : one per tick
```

`°partidas` and `°marcadores` use `°`, which initialises on first use
and survives the loop; they are the only locals that outlive a game.
