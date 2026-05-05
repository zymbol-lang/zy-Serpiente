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
| **Estado** | `abierto` · `workaround` · `propuesto` · `resuelto vX.X.X` · `descartado` · `excluido` |

---

## BUG — Comportamiento incorrecto en funcionalidad existente

Funcionalidades que Zymbol declara soportar pero que fallan en condiciones específicas encontradas durante la construcción de Serpiente.

| ID | Módulo | Contexto | Estado |
|----|--------|----------|--------|
| [BUG-001](#bug-001--items-de--consumen-tokens-de-líneas-siguientes) | `dibujo.zy` | `>>~` items · lexer descarta `\n` · `parse_output_items` sin límite de línea | resuelto v0.0.5 |
| [BUG-002](#bug-002--else-escrito-como-_-produce-error-de-parser) | `dibujo.zy` | `_?` sin condición usado como else — debería ser `_` | resuelto v0.0.5 |
| [BUG-003](#bug-003--asignación-condicional-en-loop-no-propaga-a-partir-de-la-2ª-iteración) | `serpiente.zy` | `? cond { var = expr }` en `@:label` — 2.ª iteración no actualiza `var` en scope externo | resuelto (no reproducible) |
| [BUG-004](#bug-004--mover-no-detecta-colisión-con-la-columna-derecha-del-emoji) | `logica.zy` | `mover` solo chequea la col izquierda del emoji — acceso vertical por col derecha no cuenta | resuelto |
| [BUG-005](#bug-005--igualdad-de-tuplas-siempre-0-en-el-vm) | `logica.zy` | `==` y `<>` entre tuplas siempre devuelven `#0` en `--vm` — `cmp_direct` sin arm `Tuple` | resuelto v0.0.5 |

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
- **Propuesta:** N/A — el bug no se reproduce en el intérprete actual. El workaround permanece como diseño definitivo: `tick_comida` es una función pura (más testeable, sin dependencia de efectos de scope), superior al bloque condicional original.
- **Investigación (2026-05-04):** Tres casos de prueba ejecutados (`Assignment` simple, `DestructureAssign` directo, `DestructureAssign` con `body_needs_own_scope=true`) — todos pasan. Probable resolución como efecto colateral del refactor QW7/QW16 en `if_stmt.rs` / `loops.rs`.
- **Estado:** resuelto (no reproducible; workaround `tick_comida` permanece como diseño limpio)

---

### BUG-005 · Igualdad de tuplas siempre `#0` en el VM

- **Módulo:** `logica.zy`
- **Contexto:** Operadores `==` y `<>` aplicados a valores `Tuple` en el modo `--vm`.
- **Descripción:** En el VM, cualquier comparación entre tuplas devolvía `#0` (falso) independientemente del contenido. La causa raíz estaba en dos funciones de `crates/zymbol-vm/src/lib.rs`: `cmp_direct()` (usada por la instrucción `CmpEq`) y `Value::equals()` (usada por pattern matching y `$?`). Ambas solo manejaban tipos escalares y caían en `_ => 1` (no igual) para cualquier `Value::Tuple`.
- **Síntoma en Serpiente:** El juego funciona correctamente en modo tree-walker (`zymbol run`). Con `--vm`, la primera fruta se come visualmente (la serpiente la alcanza) pero:
  - `comio` queda en `#0` — `tick_comida` no genera nueva comida
  - `puntos` no se incrementa — el marcador permanece en 0
  - La segunda fruta nunca aparece
- **Causa raíz técnica:** `mover` evalúa `cab == comida || cab == (fr_com, fc_com + 1)`. Con `cab = (15, 20)`, `comida = (15, 19)` y `(fr_com, fc_com + 1) = (15, 20)`, la expresión debería ser `#1`. En el VM, `CmpEq` llama a `cmp_direct(Tuple([15,20]), Tuple([15,20]))` que no tiene arm para `Tuple` → devuelve `1` (no igual) → `comio = #0`.
- **Caso mínimo:**
  ```zymbol
  a = (1, 2)
  b = (1, 2)
  >> (a == b) ¶   // TW: #1 — VM (bug): #0
  ```
- **Diagnóstico:** Descubierto probando `zymbol run --vm serpiente.zy` en terminal real. El TW pasaba 425/425 tests pero el VM no tenía cobertura de igualdad de tuplas.
- **Fix:** En `crates/zymbol-vm/src/lib.rs`, añadido arm recursivo en ambas funciones:
  ```rust
  // cmp_direct()
  (Value::Tuple(x), Value::Tuple(y)) => {
      if x.len() != y.len() { return 1; }
      for (a, b) in x.iter().zip(y.iter()) {
          let r = cmp_direct(a, b);
          if r != 0 { return r; }
      }
      0
  }
  // Value::equals()
  (Value::Tuple(a), Value::Tuple(b)) => {
      a.len() == b.len() && a.iter().zip(b.iter()).all(|(x, y)| x.equals(y))
  }
  ```
- **Test de regresión:** `interpreter/tests/bugs/bug_vm_tuple_equality.zy` — cubre igualdad literal, variables, aritmética en slots, condición `||` compuesta, tuplas anidadas.
- **Estado:** resuelto v0.0.5

---

## GAP — Capacidad ausente en el lenguaje

Construcciones o comportamientos que se necesitan para completar Serpiente pero que Zymbol aún no implementa.

| ID | Módulo | Capacidad ausente | Estado |
|----|--------|-------------------|--------|
| [GAP-001](#gap-001--sin-operador-de-repetición-de-string) | `dibujo.zy` | Operador `"═" $* n` — repetir string N veces | resuelto |
| [GAP-002](#gap-002--sin-número-aleatorio-nativo) | `logica.zy` | Número aleatorio nativo — `$RANDOM` requiere BashExec | descartado |
| [GAP-003](#gap-003--tuiblock-no-garantiza-cleanup-al-usar-label-en-vm) | `serpiente.zy` | `@:label!` dentro de `>>|` no ejecuta `ExitTui` en el VM | resuelto |
| [GAP-004](#gap-004--sin-detección-de-resize-del-terminal) | `serpiente.zy` | Dimensiones fijas — `>>?` no se consulta en el game loop | excluido |
| [GAP-005](#gap-005--sin-soporte-de-estilos-de-texto-en-) | `dibujo.zy` | `>>~` no soporta negrita, cursiva ni subrayado — solo color fg/bg | resuelto v0.0.5 |
| [GAP-006](#gap-006--lsp-no-reconoce--como-definición-de-variable) | `dibujo.zy` | El LSP reporta `tecla` como "undefined" tras `<<| tecla` — falso positivo | resuelto v0.0.5 |

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
- **Estado:** resuelto — implementado en lexer (`DollarStar`), parser (`parse_string_repeat`), intérprete (`eval_string_repeat`), VM (`StrRepeat`), compilador, formatter y análisis semántico. Workaround `_linea_h` eliminado en `dibujo.zy`.

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
- **Estado:** descartado — decisión de diseño: Zymbol no añade funciones que no sean primitivas del lenguaje. El workaround LCG en `logica.zy` es la solución definitiva.

---

### GAP-003 · TuiBlock no garantiza cleanup al usar `@:label!` en el VM

- **Módulo:** `serpiente.zy`
- **Capacidad ausente:** Limpieza automática del terminal (restore alternate screen, deshabilitar raw mode, mostrar cursor) al salir de `>>| { }` por `@:label!` en el VM.
- **Descripción:** En el tree-walker, el cleanup de `>>|` está implementado como un guard Rust con `Drop` — el terminal se restaura independientemente de cómo se salga del bloque (normal, `@!`, error). En el VM, `ExitTui` es una instrucción bytecode emitida al final del bloque; si `@:label!` interrumpe la ejecución antes de llegar a ella, el terminal queda en raw mode con el alternate screen activo.
- **Impacto en Serpiente:** El game loop usa `@:game!` dentro de `>>|`. En el tree-walker (modo por defecto) funciona correctamente. En el VM (`--vm`) el terminal puede quedar roto tras salir.
- **Workaround:** Usar el tree-walker (modo por defecto). No restructurar el loop evitando `@:label!`.
- **Fix:** Struct `TuiGuard` con `Drop` en `crates/zymbol-vm/src/lib.rs`. `run()` mantiene `tui_stack: Vec<TuiGuard>` — `EnterTui` hace `push`, `ExitTui` hace `pop` (el `Drop` ejecuta el cleanup). Si `ExitTui` no se alcanza (error, break externo), el Vec se destruye al salir de `run()` y el `Drop` restaura el terminal igualmente.
- **Estado:** resuelto

---

### GAP-004 · Sin detección de resize del terminal

- **Módulo:** `serpiente.zy`
- **Clasificación original:** GAP — pero incorrecta. El lenguaje ya provee `>>?` para consultar el tamaño del terminal en cualquier momento. La API es completa.
- **Diagnóstico:** No había ninguna capacidad ausente en Zymbol — la detección de resize era una decisión de diseño pendiente en el juego, no una limitación del lenguaje.
- **Decisión:** Excluido de los GAPs del lenguaje. El comportamiento se implementó en `serpiente.zy` como mejora de diseño del juego: `>>?` en cada tick de `@:game`, con `@:main>` para reiniciar la partida centrada al detectar cambio de dimensiones.
- **Estado:** excluido — no es un GAP del lenguaje

---

### GAP-005 · Sin soporte de estilos de texto en `>>~`

- **Módulo:** `dibujo.zy`
- **Capacidad ausente:** Aplicar atributos de texto ANSI — **negrita**, *cursiva* y subrayado — en la salida posicionada `>>~`.
- **Caso de uso en Serpiente:** Títulos, marcador y opciones de menú con negrita/subrayado para mayor legibilidad.
- **Diseño resuelto:** Rediseño completo de la tupla de `>>~`. Nuevo orden: `(fila, col, BKS, fg, bg)` — 5 slots donde el slot BKS (posición 3) es una máscara de bits de atributos (1=Bold, 2=Italic, 4=Underline). Sintaxis sparse con comas como marcadores de posición: `>>~(,,,15,0)>` (sin mover cursor, fg=15, bg=0).
- **Breaking change:** El tercer slot pasó de ser `fg` a ser `BKS`. Todas las llamadas en `dibujo.zy` migradas de `>>~(fila, col, fg)` a `>>~(fila, col, 0, fg)`.
- **Implementación:**
  - AST: `OutputPos.pos: Box<Expr>` → `OutputPos.slots: Vec<Option<Expr>>`
  - Parser: `parse_sparse_pos_tuple()` — slots vacíos = `None`, máximo 5 slots
  - Intérprete: `execute_output_pos()` con `Option<i64>` por slot; presencia del slot (no valor cero) determina si se aplica; `Attribute::Reset` (ESC[0m) al final si se aplicó algo
  - VM: `vm_extract_pos()` retorna `(Option<u16>, Option<u16>, i64, Option<i64>, Option<i64>)`; `PrintAt` actualizado con BKS y reset
  - Compilador: emite `LoadUnit` para slots `None`, `MakeTuple` con los 5 registros
  - `dibujo.zy`: transformación masiva `(fila, col, fg)` → `(fila, col, 0, fg)` en todas las llamadas
- **Estado:** resuelto v0.0.5

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
- **Fix:** En `zymbol-semantic/src/type_check.rs`, añadido `Statement::KeyInput(ki)` en dos lugares: en `check_statement()` (define la variable como `ZymbolType::Char` al llegar a la sentencia) y en `define_local_vars_from_block()` (pre-declara la variable durante inferencia de firma de función). La causa raíz era que `KeyInput` caía en el `_ => {}` del type checker sin registrar la variable en el scope de resolución.
- **Estado:** resuelto v0.0.5

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

| Categoría | Total | Abiertos | Con workaround | Propuestos | Resueltos | Descartados | Excluidos |
|-----------|-------|----------|----------------|------------|-----------|-------------|-----------|
| BUG | 5 | 0 | 0 | 0 | 5 | 0 | 0 |
| GAP | 6 | 0 | 0 | 0 | 4 | 1 | 1 |
| ERROR | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| IDEA | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| **Total** | **12** | **2** | **0** | **1** | **9** | **1** | **1** |

---

## Historial de resoluciones

Entradas movidas aquí cuando pasan a estado `resuelto`.

| ID | Título | Resuelto en | Cómo |
|----|--------|-------------|------|
| BUG-001 | Items de `>>~` consumen tokens de líneas siguientes | v0.0.5 | `parse_output_items_same_line(line)` en `io.rs`: para si `peek().span.start.line != line`. `parse_output_item_postfix` en `expressions.rs`: check de línea al inicio del loop para no cruzar `\n`. |
| BUG-002 | Else escrito como `_?` produce error de parser | v0.0.5 | Uso de `_` en lugar de `_?` para else sin condición. Diagnóstico mejorado en `if_stmt.rs`: guard `LBrace` tras `_?` emite `"'_?' requires a condition"` con `help: use '_' (without '?') for an unconditional else branch`. |
| GAP-001 | Sin operador de repetición de string | v0.0.5 | Operador `$*` implementado en lexer (`DollarStar`), parser (`parse_string_repeat`), intérprete (`eval_string_repeat`), VM (`StrRepeat`), compilador, formatter y análisis semántico. Workaround `_linea_h` eliminado. |
| GAP-003 | TuiBlock no garantiza cleanup al usar `@:label!` en el VM | v0.0.5 | `struct TuiGuard` con `Drop` en `zymbol-vm/src/lib.rs`. `run()` mantiene `tui_stack: Vec<TuiGuard>` — `EnterTui` push, `ExitTui` pop. Cleanup garantizado en cualquier ruta de salida. |
| GAP-005 | Sin soporte de estilos de texto en `>>~` | v0.0.5 | Nuevo orden de slots `(fila, col, BKS, fg, bg)` + sintaxis sparse `>>~(,,,fg,bg)>`. BKS = bitmask 1=Bold/2=Italic/4=Underline. Slot ausente = `None` = no tocar ese parámetro. `Attribute::Reset` al finalizar. `dibujo.zy` migrado de 3 → 4 args en todas las llamadas. |
| GAP-006 | LSP no reconoce `<<|` como definición de variable | v0.0.5 | En `type_check.rs`: `Statement::KeyInput` añadido en `check_statement()` y `define_local_vars_from_block()`. La variable se registra como `ZymbolType::Char` — el mismo tipo que produce `<<|` en runtime. |
| BUG-005 | Igualdad de tuplas siempre `#0` en el VM | v0.0.5 | En `zymbol-vm/src/lib.rs`: arm `(Tuple, Tuple)` añadido a `cmp_direct()` (comparación lexicográfica recursiva) y a `Value::equals()` (igualdad elemento a elemento). Descubierto probando `zymbol run --vm serpiente.zy` — el marcador de puntos no incrementaba al comer la primera fruta. |

---

## Historial de descartes

Entradas movidas aquí cuando la propuesta se evalúa y se decide no implementar.

| ID | Título | Decisión | Razón |
|----|--------|----------|-------|
| GAP-002 | Sin número aleatorio nativo | descartado | Decisión de diseño: Zymbol no añade funciones que no sean primitivas del lenguaje. LCG en `logica.zy` es la solución definitiva. |
| GAP-004 | Sin detección de resize del terminal | excluido | No era un GAP del lenguaje — `>>?` ya soporta consulta de tamaño en cualquier momento. Era una decisión de diseño pendiente en el juego, implementada en `serpiente.zy`. |
