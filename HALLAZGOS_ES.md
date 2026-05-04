# HALLAZGOS · Serpiente

> Registro vivo de BUGs, GAPs, ERRORs e IDEAs descubiertos durante la construcción de Serpiente.  
> Serpiente es el primer programa TUI real en Zymbol — estos hallazgos documentan los límites
> que un game loop en terminal expone al lenguaje.  
> Este documento alimenta directamente el roadmap de Zymbol v0.0.6 y versiones futuras.

---

## Cómo leer este documento

| Campo | Significado |
|-------|-------------|
| **ID** | Identificador único. Formato: `TIPO-NNN` |
| **Módulo** | Archivo `.zy` donde se encontró el problema |
| **Contexto** | Construcción exacta de Zymbol involucrada |
| **Descripción** | Qué falla, qué falta o qué se propone |
| **Workaround** | Solución temporal utilizada en Serpiente |
| **Propuesta** | Cómo debería resolverse en el lenguaje |
| **Estado** | `abierto` · `workaround` · `propuesto` · `resuelto vX.X.X` |

---

## BUG — Comportamiento incorrecto en funcionalidad existente

Funcionalidades que Zymbol declara soportar pero que fallan en condiciones específicas encontradas durante la construcción de Serpiente.

| ID | Módulo | Contexto | Estado |
|----|--------|----------|--------|
| [BUG-001](#bug-001--items-de--consumen-tokens-de-líneas-siguientes) | `dibujo.zy` | `>>~` items · lexer descarta `\n` · `parse_output_items` sin límite de línea | resuelto v0.0.5 |
| [BUG-002](#bug-002--else-escrito-como-_-produce-error-de-parser) | `dibujo.zy` | `_?` sin condición usado como else — debería ser `_` | resuelto v0.0.5 |
| [BUG-003](#bug-003--asignación-condicional-en-loop-no-propaga-a-partir-de-la-2ª-iteración) | `serpiente.zy` | `? cond { var = expr }` en `@:label` — 2.ª iteración no actualiza `var` en scope externo | workaround |
| [BUG-004](#bug-004--mover-no-detecta-colisión-con-la-columna-derecha-del-emoji) | `logica.zy` | `mover` solo chequea la col izquierda del emoji — acceso vertical por col derecha no cuenta | resuelto |

---

### BUG-001 · Items de `>>~` consumen tokens de líneas siguientes

- **Módulo:** `dibujo.zy`
- **Contexto:** Sentencias `>>~` consecutivas dentro del cuerpo de una función.
- **Descripción:** El parser de `>>~` seguía consumiendo tokens de líneas posteriores como parte de la lista de items. El lexer descarta `\n` como whitespace (no genera token `Newline`), y `parse_output_items` solo paraba ante `¶`, `\\`, `}` o EOF. Resultado: dos `>>~` consecutivas se fundían en una sola, y los tokens de la línea siguiente se interpretaban como items adicionales de la primera. La misma causa raíz también hacía que `parse_output_item_postfix` consumiera `[`, `.`, `(` de la línea siguiente — por ejemplo `"x"\n[arr]` se parseaba como `"x"[arr]`.
- **Caso mínimo:**
  ```zymbol
  >>~ (1, 1) > "header"
  [fy, fx] = comida        // error: 'fy' tratado como output item, '=' inesperado
  >>~ (2, 1) > "body"      // error: OutputPos inesperado en expresión
  ```
- **Error observado:**
  ```
  error: expected expression, found OutputPos
    --> render.zy:40:9
    40 |         >>~ pos_bot > "╚" _linea_h(BW) "╝"
       |         ^^^
  ```
- **Workaround:** Pre-computar posiciones con aritmética como variables separadas y colocar una sentencia por línea, sin omitir líneas en blanco entre `>>~` consecutivas. Workaround eliminado tras el fix.
- **Propuesta:** `parse_output_pos` debe usar el número de línea del token `>>~` para delimitar sus items. `parse_output_item_postfix` debe detener la búsqueda de operadores postfix al cruzar línea fuente.
- **Estado:** resuelto v0.0.5

---

### BUG-002 · Else escrito como `_?` produce error de parser

- **Módulo:** `dibujo.zy`
- **Contexto:** Rama `else` en bloque `? cond { } _ { }` dentro del loop de dibujado de la serpiente.
- **Descripción:** `_?` es el operador `else-if` en Zymbol y **requiere una condición** (`_? cond { }`). Usarlo sin condición como sustituto de `_` (else) produce "expected expression, found LBrace" apuntando al `{` de apertura de la rama. El error no orienta al programador hacia la construcción correcta.
- **Caso mínimo:**
  ```zymbol
  ? i == 1 {
      >>~ (sy, sx, CABEZA) > "@"
  } _? {             // error: expected expression, found LBrace
      >>~ (sy, sx, VERDE) > "█"
  }
  ```
- **Error observado:**
  ```
  error: expected expression, found LBrace
    --> render.zy:66:18
    66 |             } _? {
       |                 ^
  ```
- **Workaround:** Usar `_` en lugar de `_?` para la rama else sin condición:
  ```zymbol
  ? i == 1 {
      >>~ (sy, sx, CABEZA) > "@"
  } _ {              // ✓ else sin condición
      >>~ (sy, sx, VERDE) > "█"
  }
  ```
- **Propuesta:** El mensaje de error al encontrar `_?` sin condición debería incluir un `help:` que oriente: `use '_' (without '?') for unconditional else`. Actualmente el error apunta al `{` sin explicar que el problema está en `_?`.
- **Estado:** resuelto v0.0.5

---

### BUG-004 · `mover` no detecta colisión con la columna derecha del emoji

- **Módulo:** `logica.zy`
- **Contexto:** Función `mover` — detección de comida con `cab == comida`.
- **Descripción:** Los emojis de fruta son 2 columnas de ancho en la terminal. La comida se almacena en su columna izquierda `(fr, fc)`. `mover` solo verificaba `cab == comida` (columna izquierda). Al aproximarse verticalmente por la columna derecha `(fr, fc+1)`, la serpiente visualmente toca la fruta pero `comio` queda en `#0`. La comida no se regenera y el juego queda bloqueado esperando que la cabeza pase exactamente por `(fr, fc)` — posición a la que nunca vuelve si el movimiento fue vertical.
- **Condición exacta de fallo:** Movimiento arriba-abajo o abajo-arriba pasando por `(fr, fc+1)` — la segunda columna del emoji.
- **Caso concreto reportado:** Fruta en `(16, 19)` → serpiente pasa por `(16, 20)` → visualmente comida pero `comio=#0`.
- **Fix en `mover`:**
  ```zymbol
  [fr_com, fc_com] = comida
  ? cab == comida || cab == (fr_com, fc_com + 1) {
      serpiente = serpiente$+[1] cab
      puntos = puntos + 1
      <~ (#1, serpiente, puntos, #1, cab)
  }
  ```
- **Fix en `dibujar`:** Cuando `comio=#1`, borrar 2 columnas en `comida_vieja` antes de dibujar la cabeza (cubre el caso donde la cabeza entró por la col derecha y la col izquierda del emoji quedaría visible):
  ```zymbol
  ? comio {
      [fvy, fvx] = comida_vieja
      >>~ (fvy, fvx, 0) > "  "
  }
  >>~ (fy_cab, fx_cab, 2) > _char_cabeza(serpiente[1], serpiente[2])
  ```
- **Estado:** resuelto

---

### BUG-003 · Asignación condicional en loop no propaga a partir de la 2.ª iteración

- **Módulo:** `serpiente.zy`
- **Contexto:** Variables (`comida`, `fruta`, `semilla`) asignadas dentro de un bloque `? cond { }` en el cuerpo de un loop `@:label { }`.
- **Descripción:** En la 1.ª iteración en que la condición es `#1`, las asignaciones dentro del bloque se propagan al scope del loop. En la 2.ª iteración, aunque la condición vuelva a ser `#1`, las variables NO se actualizan — el scope externo retiene los valores de la 1.ª asignación condicional.
- **Síntomas en Serpiente:**
  - La 1.ª fruta se come y aparece la 2.ª ✓
  - La 2.ª fruta se come pero NO aparece la 3.ª ✗
  - El puntaje se queda en `1` en lugar de actualizarse a `2` ✗
- **Caso mínimo:**
  ```zymbol
  comida  = (5, 5)
  fruta   = "🍎"
  semilla = 42
  comio   = #1
  @:game {
      // En la 2.ª iteración con comio=#1, comida/fruta/semilla NO se actualizan
      ? comio {
          [comida,  semilla] = l::nueva_comida(serpiente, AN, AL, semilla)
          [fruta,   semilla] = l::fruta_aleatoria(semilla)
      }
      d::dibujar(serpiente, cola_vieja, comio, comida_vieja, comida, fruta, puntos, AN, AL)
  }
  ```
- **Workaround:** Extraer la lógica a una función `tick_comida` que recibe los valores actuales y retorna los nuevos — la asignación en el caller es siempre incondicional:
  ```zymbol
  [comida, fruta, semilla] = l::tick_comida(comio, serpiente, AN, AL, semilla, comida, fruta)
  ```
- **Propuesta:** El tree-walker debe propagar asignaciones de variables del scope externo realizadas dentro de bloques `? cond { }` en todos los ticks del loop, no solo el primero. Investigar si el closure del bloque crea un scope hijo nuevo en cada iteración o reutiliza el del loop.
- **Estado:** workaround (implementado en `logica.zy::tick_comida`)

---

## GAP — Capacidad ausente en el lenguaje

Construcciones o comportamientos que se necesitan para completar Serpiente pero que Zymbol aún no implementa.

| ID | Módulo | Capacidad ausente | Estado |
|----|--------|-------------------|--------|
| [GAP-001](#gap-001--sin-operador-de-repetición-de-string) | `dibujo.zy` | Operador `"═" $* n` — repetir string N veces | abierto |
| [GAP-002](#gap-002--sin-número-aleatorio-nativo) | `logica.zy` | Número aleatorio nativo — `$RANDOM` requiere BashExec | abierto |
| [GAP-003](#gap-003--tuiblock-no-garantiza-cleanup-al-usar-label-en-vm) | `serpiente.zy` | `@:label!` dentro de `>>|` no ejecuta `ExitTui` en el VM | abierto |
| [GAP-004](#gap-004--sin-detección-de-resize-del-terminal) | `serpiente.zy` | Dimensiones fijas — `>>?` no se consulta en el game loop | abierto |
| [GAP-005](#gap-005--sin-soporte-de-estilos-de-texto-en-) | `dibujo.zy` | `>>~` no soporta negrita, cursiva ni subrayado — solo color fg/bg | abierto |
| [GAP-006](#gap-006--lsp-no-reconoce--como-definición-de-variable) | `dibujo.zy` | El LSP reporta `tecla` como "undefined" tras `<<| tecla` — falso positivo | abierto |

---

### GAP-001 · Sin operador de repetición de string

- **Módulo:** `dibujo.zy`
- **Capacidad ausente:** Repetir un string N veces — `"═" $* n` o equivalente. Actualmente Zymbol no tiene este operador.
- **Caso de uso en Serpiente:** Construir la línea horizontal del borde del tablero (`"─" $* AN`) requiere un helper de 7 líneas.
- **Workaround actual:** Función privada `_linea_h(n)` con loop explícito:
  ```zymbol
  _linea_h(n) {
      s = ""
      i = 1
      @ i <= n {
          s = s $++ "═"
          i++
      }
      <~ s
  }
  ```
- **Propuesta:** Operador `$*` para string — `str $* n` devuelve `str` repetido `n` veces. Coherente con el prefijo `$` de todos los operadores de colección y string:
  ```zymbol
  linea = "─" $* AN
  >>~ (1, 1, BORDE) > "╭" linea "╮"
  ```
- **Estado:** abierto

---

### GAP-002 · Sin número aleatorio nativo

- **Módulo:** `logica.zy`
- **Capacidad ausente:** Generación de números aleatorios sin depender de shell. Toda aleatoriedad en Zymbol requiere BashExec con `$RANDOM` de bash.
- **Caso de uso en Serpiente:** Spawn de comida en posición aleatoria dentro del tablero. Cada llamada a `rand_pos(max)` lanza un subproceso de shell.
- **Workaround actual:**
  ```zymbol
  rand_pos(max) {
      raw = <\ "echo $((RANDOM % " max " + 2))" \>
      <~ #|raw|
  }
  ```
- **Limitaciones del workaround:**
  - Requiere disponibilidad de shell (`/bin/bash` o compatible)
  - `$RANDOM` rango 0..32767 — adecuado para coordenadas, inadecuado para criptografía
  - Latencia visible en sistemas lentos (cada spawn de subproceso = ~5-15ms)
  - El cast `#|raw|` falla si BashExec devuelve contenido inesperado (ej. stderr)
- **Propuesta:** Módulo `std/random` o función built-in:
  ```zymbol
  fc = rand(2, AN)    // entero aleatorio en [2, AN]
  ```
- **Estado:** abierto

---

### GAP-003 · TuiBlock no garantiza cleanup al usar `@:label!` en el VM

- **Módulo:** `serpiente.zy`
- **Capacidad ausente:** Limpieza automática del terminal (restore alternate screen, deshabilitar raw mode, mostrar cursor) al salir de `>>| { }` por `@:label!` en el VM.
- **Descripción:** En el tree-walker, el cleanup de `>>|` está implementado como un guard Rust con `Drop` — el terminal se restaura independientemente de cómo se salga del bloque (normal, `@!`, error). En el VM, `ExitTui` es una instrucción bytecode emitida al final del bloque; si `@:label!` interrumpe la ejecución antes de llegar a ella, el terminal queda en raw mode con el alternate screen activo.
- **Impacto en Serpiente:** El game loop usa `@:game!` dentro de `>>|`. En el tree-walker (modo por defecto) funciona correctamente. En el VM (`--vm`) el terminal puede quedar roto tras salir.
- **Workaround:** Usar el tree-walker (modo por defecto). No restructurar el loop evitando `@:label!`.
- **Propuesta:** El VM debe instalar el mismo guard Rust con `Drop` que usa el tree-walker al ejecutar `EnterTui`, de modo que `ExitTui` se garantice en cualquier ruta de salida. Deuda técnica documentada en `crates/zymbol-vm/src/lib.rs` con comentario `// TODO: TuiBlock cleanup on break`.
- **Estado:** abierto

---

### GAP-004 · Sin detección de resize del terminal

- **Módulo:** `serpiente.zy`
- **Capacidad ausente:** Detección de cambio de tamaño de terminal durante la partida. `>>?` se consulta al arrancar y el tablero se adapta al tamaño real en ese momento, pero no se vuelve a consultar en cada tick del game loop.
- **Descripción:** Un Snake de producción consultaría `>>?` en cada iteración para detectar resize de ventana (tiling WM, pantalla completa ↔ ventana) y redibujar el tablero adaptado. La API ya soporta esto — el gap es de diseño en Serpiente, no del lenguaje.
- **Estado actual:** Las dimensiones se fijan al inicio via `[filas, cols] = >>?` — correcto para el tamaño inicial, pero si el usuario redimensiona la terminal durante la partida el tablero queda desalineado.
- **Propuesta de diseño:**
  ```zymbol
  @:game {
      <<|? tecla
      [filas, cols] = >>?
      ? filas <> ult_filas || cols <> ult_cols {
          AL = filas - 2
          AN = cols  - 2
          ult_filas = filas
          ult_cols  = cols
      }
      // ... resto del loop
  }
  ```
- **Estado:** abierto

---

### GAP-005 · Sin soporte de estilos de texto en `>>~`

- **Módulo:** `dibujo.zy`
- **Capacidad ausente:** Aplicar atributos de texto ANSI — **negrita**, *cursiva* y subrayado — en la salida posicionada `>>~`. Actualmente la tupla de posición solo acepta color `(fila, col, fg, bg)`.
- **Caso de uso en Serpiente:** El título "GAME OVER", el marcador de puntos, las opciones del menú y los encabezados de ayuda serían más legibles y expresivos en negrita o subrayado. Hoy solo se puede cambiar el color.
- **Motivación concreta:**
  ```zymbol
  // Deseado — negrita en el puntaje final
  >>~ (fila_c+5, col_c, TEXTO, negrita) > "Puntaje final: " puntos
  // Deseado — subrayado en la opción seleccionada del menú
  >>~ (fila_c+7, col_c, VERDE, subrayado) > "► Nuevo juego"
  ```
- **Limitación actual:** Para lograr negrita/subrayado hay que inyectar secuencias ANSI crudas dentro de un string — frágil, no portable y rompe la abstracción del lenguaje:
  ```zymbol
  // Workaround horrible — secuencia ANSI hardcodeada
  >>~ (fila_c+5, col_c, TEXTO) > "\e[1mPuntaje final: " puntos "\e[0m"
  ```
- **Propuesta A — atributos en la tupla de posición:**
  Extender la tupla a `(fila, col, fg, bg, estilo)` donde `estilo` es una máscara de bits (o constante simbólica):
  ```zymbol
  NEGRITA    := 1
  CURSIVA    := 2
  SUBRAYADO  := 4

  >>~ (fila, col, VERDE, 0, NEGRITA) > "► Nuevo juego"
  >>~ (fila, col, ROJO,  0, NEGRITA | SUBRAYADO) > "GAME OVER"
  ```
- **Propuesta B — módulo `std/ansi` con constantes de estilo:**
  Igual que IDEA-001 pero extendido a estilos. Las constantes de fg, bg y estilo se importan del mismo módulo:
  ```zymbol
  <# std/ansi <= ansi

  >>~ (fila, col, ansi.VERDE, 0, ansi.NEGRITA) > "► Nuevo juego"
  ```
- **Propuesta C — operadores de formato de string (más ambicioso):**
  Nuevos operadores de estilo que envuelven un valor en las secuencias ANSI correctas, sin tocar la sintaxis de `>>~`:
  ```zymbol
  >>~ (fila, col, VERDE) > $bold("► Nuevo juego")
  >>~ (fila, col, ROJO)  > $bold($underline("GAME OVER"))
  ```
- **Impacto estimado:** Mejora visual significativa para cualquier TUI en Zymbol. La Propuesta A es la de menor complejidad de implementación (solo ampliar el parser de la tupla y el runtime de `>>~`/`PrintAt`).
- **Estado:** abierto

---

### GAP-006 · LSP no reconoce `<<|` como definición de variable

- **Módulo:** `dibujo.zy` (también afecta cualquier archivo `.zy` que use `<<|`)
- **Capacidad ausente:** El analizador semántico del LSP (`zymbol-analyzer`) no registra `<<| var` ni `<<|? var` como definiciones de variable. Trata la variable leída como si nunca hubiera sido declarada.
- **Síntoma:** El LSP emite diagnósticos `severity: 8` (error) en cada uso posterior de `tecla` (u otra variable de lectura) dentro del mismo bloque, a pesar de que el runtime ejecuta el código correctamente.
- **Código afectado en `dibujo.zy`:** Todas las funciones que usan `<<|` seguido de condiciones sobre la variable leída:
  ```zymbol
  @:sel {
      <<| tecla              // LSP: ok — sentencia reconocida
      ? tecla == '1' { ... } // LSP: error — "undefined variable 'tecla'"
      ? tecla == '2' { ... } // LSP: error
      sel = _mover_sel(tecla, sel, 5)  // LSP: error
  }
  ```
- **Líneas reportadas** (versión actual): 108–113, 121, 165, 281–284, 290 de `dibujo.zy`.
- **Causa raíz:** El pase de resolución de variables en `zymbol-semantic` / `zymbol-analyzer` procesa `KeyInput` como una sentencia de efecto de lado, pero no inserta la variable destino en el scope de resolución. Las sentencias de asignación normal (`var = expr`) sí insertan la variable; `<<|` no.
- **Impacto:** Solo cosmético en el flujo de desarrollo — el código compila y ejecuta sin error. Pero genera ruido en el panel de problemas del editor, oculta errores reales y degrada la experiencia con el LSP.
- **Propuesta:** En el visitor/resolver de `zymbol-semantic` y en el indexer de `zymbol-analyzer`, tratar `KeyInput { variable }` idénticamente a una asignación `variable = expr` para efectos de registro en el scope:
  ```rust
  // En zymbol-semantic/src/lib.rs — visitor de Statement::KeyInput
  Statement::KeyInput(ki) => {
      scope.define(ki.variable.clone(), Type::Char);
      // ... resto del análisis
  }
  ```
  Mismo ajuste en `zymbol-analyzer` para que el hover y el completion también reconozcan la variable.
- **Estado:** abierto

---

## ERROR — Error de compilación o runtime no documentado

Errores producidos por el intérprete o compilador que apuntan a una limitación no documentada del lenguaje.

| ID | Módulo | Error producido | Estado |
|----|--------|-----------------|--------|
| — | — | — | — |

---

## IDEA — Propuestas de mejora al lenguaje

Mejoras al lenguaje Zymbol inspiradas directamente en la experiencia de construir Serpiente.

| ID | Área | Resumen | Estado |
|----|------|---------|--------|
| [IDEA-001](#idea-001--sintaxis-de-color-en-) | sintaxis | Constantes de color ANSI como parte del vocabulario de `>>~` | propuesto |

---

### IDEA-001 · Sintaxis de color en `>>~`

- **Área:** sintaxis
- **Motivación:** Los colores ANSI se pasan como enteros en la tupla de posición de `>>~` — `(row, col, fg, bg)`. El significado de `8`, `10`, `11` no es obvio sin referencia externa. Cada módulo que usa colores define sus propias constantes con `:=`:
  ```zymbol
  BORDE  := 8    // dark gray
  VERDE  := 10   // bright green
  COMIDA := 11   // bright yellow
  ```
  Esto funciona, pero en programas más grandes la gestión de paletas se vuelve manual.
- **Propuesta:** Un módulo estándar `std/ansi` que exporte constantes para los 256 colores ANSI más comunes, con nombres descriptivos:
  ```zymbol
  <# std/ansi <= color

  >>~ (row, col, color.BRIGHT_GREEN) > "█"
  >>~ (row, col, color.BRIGHT_YELLOW) > "◆"
  ```
  Sin cambios en la sintaxis de `>>~` — solo una librería de constantes con nombres legibles.
- **Impacto estimado:** Mejora de legibilidad en cualquier programa TUI. Sin breaking changes.
- **Estado:** propuesto

---

## Resumen de estado

| Categoría | Total | Abiertos | Con workaround | Propuestos | Resueltos | Descartados |
|-----------|-------|----------|----------------|------------|-----------|-------------|
| BUG | 4 | 0 | 1 | 0 | 3 | 0 |
| GAP | 6 | 6 | 0 | 0 | 0 | 0 |
| ERROR | 0 | 0 | 0 | 0 | 0 | 0 |
| IDEA | 1 | 0 | 0 | 1 | 0 | 0 |
| **Total** | **11** | **6** | **1** | **1** | **3** | **0** |

---

## Historial de resoluciones

Entradas movidas aquí cuando pasan a estado `resuelto`.

| ID | Título | Resuelto en | Cómo |
|----|--------|-------------|------|
| BUG-001 | Items de `>>~` consumen tokens de líneas siguientes | v0.0.5 | `parse_output_items_same_line(line)` en `io.rs`: para si `peek().span.start.line != line`. `parse_output_item_postfix` en `expressions.rs`: check de línea al inicio del loop para no cruzar `\n`. |
| BUG-002 | Else escrito como `_?` produce error de parser | v0.0.5 | Uso de `_` en lugar de `_?` para else sin condición. El diagnóstico del parser no se mejoró — pendiente como mejora de UX. |

---

## Historial de descartes

Entradas movidas aquí cuando la propuesta se evalúa y se decide no implementar.

| ID | Título | Decisión | Razón |
|----|--------|----------|-------|
| — | — | — | — |
