# Auditoría de i18n — Serpiente (zy-Serpiente)

Revisión del sistema de internacionalización del proyecto, hecha el **2026-07-26**
contra Zymbol **v0.0.8**.

A diferencia de [HALLAZGOS_ES.md](HALLAZGOS_ES.md), que registra carencias **del
lenguaje**, este documento registra carencias **del proyecto**.

**Resumen: Serpiente no tiene i18n.** Es monolingüe en español, con el texto
incrustado dentro de marcos de ancho fijo tecleados a mano. Fue el primer TUI real
del lenguaje (v0.0.5) y se escribió antes de que existiera ninguna doctrina de i18n
y antes de que existiera `std/term`. La doctrina está ahora en
[interpreter/USERAPPI18N.md](../interpreter/USERAPPI18N.md) y la referencia
implementada en [囲碁](../GO/).

| ID | Tipo | Descripción | Estado |
|----|------|-------------|--------|
| [SRP-I18N-001](#srp-i18n-001--no-hay-ninguna-capa-de-i18n) | Carencia | ~40 cadenas en español incrustadas en `dibujo.zy`; ningún despachador, ningún catálogo, ningún gate | **Corregido** |
| [SRP-I18N-002](#srp-i18n-002--los-marcos-son-literales-de-ancho-fijo) | Bloqueante | Las cuatro pantallas son cajas dibujadas carácter a carácter; el relleno está tecleado | **Corregido** |
| [SRP-I18N-003](#srp-i18n-003--el-marcador-se-posiciona-con-constantes-derivadas-del-español) | Bug latente | `_marcador` calcula columnas a partir de la longitud de `" ✦ PUNTOS "` | **Corregido** |
| [SRP-I18N-004](#srp-i18n-004--convención-de-módulo-anterior-a-la-del-punto) | ~~Convención~~ | ~~`# dibujo` en vez de `# .dibujo`~~ | **Retirado** — era correcto |
| [SRP-I18N-005](#srp-i18n-005--el-idioma-solo-se-elegía-al-arrancar) | Cobertura | Dos puntos de entrada, pero ninguna forma de cambiar de idioma desde dentro | **Corregido** |

---

## SRP-I18N-001 · No hay ninguna capa de i18n

- **Archivo:** `dibujo.zy`
- **Descripción:** todo el texto visible está escrito en español dentro de las
  llamadas de dibujo. Cuatro pantallas:

  | Pantalla | Función | Líneas |
  |---|---|---|
  | Menú de velocidad | `menu_velocidad` | L79–L98 |
  | Ayuda | `_ayuda` | L124–L139 |
  | Pausa | `pausa` | L148–L153 |
  | Fin de juego | `fin_juego` | L270–L283 |

  No hay módulo de idioma, ni catálogo de claves, ni códigos de locale, ni punto
  de entrada alternativo, ni prueba que verifique nada de lo anterior. `README.md`
  no menciona i18n, y con razón: no la hay.

- **Por qué importa:** Serpiente es el proyecto de validación más visible del
  lenguaje y el primero que se lee. Zymbol se presenta como un lenguaje simbólico
  sin palabras clave, cuyo argumento central es que el código no está atado a
  ningún idioma humano — y su programa insignia solo habla español.
- **Opción:** retrofit completo siguiendo el patrón de 囲碁: despachador con estado
  de módulo, claves en español con prefijo de dominio (`menú.título`,
  `ayuda.arriba`, `fin.récord`), locales `español` / `english`, mensajes compuestos
  para el marcador y el contador de partidas, gate ejecutable, y dos puntos de
  entrada (`serpiente.zy` en español, `snake.zy` en inglés).
- **Solución aplicada (2026-07-26):** hecho tal cual. `idioma/despacho.zy` guarda el
  idioma como estado de módulo, así que **ninguna función de `dibujo.zy` lleva un
  parámetro de idioma**. 31 claves en español con prefijo de dominio, dos idiomas, y
  dos frases compuestas (`marcador(n)` y `texto_partida(n)`, con rama para la primera
  partida) que una tabla estática no podría producir.
  `pruebas/verificación_idioma.zy` recorre 31 × 2 y además ejercita las frases y los
  marcos; corre en los dos motores desde `pruebas/todas.sh`.
- **Consecuencia estructural:** el cuerpo del juego se movió a `juego.zy` para que
  los puntos de entrada sean lo que deben ser — un archivo por idioma cuyo único
  trabajo es `juego::iniciar("es")` o `juego::iniciar("en")`.

---

## SRP-I18N-002 · Los marcos son literales de ancho fijo

- **Archivo:** `dibujo.zy` L79–L98, L124–L139, L148–L153, L270–L283
- **Descripción:** cada fila de cada caja es una cadena completa con el relleno
  contado a mano por quien la escribió:

  ```zymbol
  >>~ (fila_c+4,  col_c, 0, TEXTO) > "│   Elige tu velocidad:        │"
  >>~ (fila_c+6,  col_c, 0, 15)  > "│   [1]  Lento      160 ms     │"
  >>~ (fila_c+7,  col_c, 0, 15)  > "│   [2]  Normal     130 ms     │"
  ```

  Y la fila seleccionada se redibuja como **otra** cadena completa, con el mismo
  relleno recalculado a mano para dejar sitio al `►`:

  ```zymbol
  ? sel == 1 { >>~ (fila_c+6,  col_c, 0, 10) > "│ ► [1]  Lento      160 ms     │" }
  ```

  Cinco opciones × dos estados = diez literales para un menú de cinco entradas.
  El menú de ayuda tiene su texto partido a mano entre tres filas
  (`"│  Al comer: la serpiente crece│"` / `"│  por la cola en el siguiente │"` /
  `"│  tick de reloj.              │"`) para caber en 30 columnas.

- **Por qué importa:** esto es lo que hace que SRP-I18N-001 no sea un retrofit
  trivial. Traducir `"Elige tu velocidad:"` a `"Choose your speed:"` deja la caja
  descuadrada, porque el relleno vive dentro de la misma cadena que el texto.
  Cualquier idioma nuevo obliga a redibujar las cuatro pantallas enteras a mano.
  En japonés o chino ni siquiera es cuestión de contar caracteres: cada glifo ocupa
  dos columnas.
- **Solución disponible desde v0.0.8:** `std/term` (`width`, `pad_left`,
  `pad_right`, `center`, `truncate`), que mide **columnas de terminal**, no
  grafemas. Los marcos se construyen midiendo el contenido más ancho del locale
  activo, como en `GO/表示/描画.zy`. Serpiente todavía apunta a v0.0.5 en su
  `README.md`; el retrofit implica subirlo a v0.0.8.
- **Solución aplicada (2026-07-26):** `texto.zy` es la capa en español sobre
  `std/term` y `marco.zy` construye los paneles. Las cuatro pantallas se arman a
  partir de listas de líneas ya traducidas; el ancho sale de la más ancha del idioma
  activo. Dos detalles que hacían falta:
  - la marca `►` se añade **antes** de medir, para que el marco tenga sitio para ella
    en cualquier idioma y las filas no se muevan al mover el cursor — lo que elimina
    la mitad de los literales (los diez del menú pasan a ser un bucle sobre cinco
    etiquetas);
  - centrar una línea hay que hacerlo **dentro** de `construir`, no antes: el ancho
    del marco no se conoce hasta haber medido todas las líneas, así que un título
    centrado contra un ancho supuesto queda descentrado en cuanto otra línea del
    panel es más larga. De ahí el prefijo `marco.CENTRADO`.

  El proyecto sube a **v0.0.8**, que es donde vive `std/term`.

---

## SRP-I18N-003 · El marcador se posiciona con constantes derivadas del español

- **Archivo:** `dibujo.zy` L62–L69
- **Descripción:**

  ```zymbol
  _marcador(puntos, AN) {
      col_m = AN / 2 - 7
      >>~ (1, col_m, 0,      8) > "┤"
      >>~ (1, col_m + 1, 0, 14) > " ✦ PUNTOS "
      >>~ (1, col_m + 10, 0, 11) > puntos
      >>~ (1, col_m + 12, 0, 14) > " ✦ "
      >>~ (1, col_m + 15, 0,  8) > "├"
  }
  ```

  Los cinco desplazamientos (`-7`, `+1`, `+10`, `+12`, `+15`) están derivados de la
  longitud de `" ✦ PUNTOS "` en español y del supuesto de que la puntuación cabe en
  dos dígitos. Con `"SCORE"` el marcador queda descentrado y con la puntuación de
  tres cifras el `✦` de la derecha se solapa.

- **Por qué importa:** es el único texto que se dibuja **durante** la partida, sobre
  el borde superior del tablero. Un descuadre aquí no es una pantalla fea: corrompe
  el borde del campo de juego, que es a la vez elemento de colisión.
- **Opción:** el marcador pasa a componerse como una sola cadena traducida
  (`texto_puntaje(n)` en el locale) y a centrarse con `std/term::center` sobre el
  ancho real medido, en vez de con desplazamientos constantes.
- **Solución aplicada (2026-07-26):** el idioma compone la insignia entera
  (`idioma::marcador(puntos)`) y `_marcador` solo la mide y la centra. Los cinco
  desplazamientos constantes desaparecieron. El gate comprueba, para los dos idiomas
  y con puntajes de 1, 2 y 4 dígitos, que los dos corchetes caen dentro del borde.

---

## SRP-I18N-004 · ~~Convención de módulo anterior a la del punto~~ — retirado

- **Hallazgo original:** `# dibujo {` no lleva prefijo de punto, a diferencia de
  `# .表示_描画` en 囲碁.
- **Por qué se retira:** era un error de lectura mío. El punto no marca «convención
  nueva»: marca **subcarpeta**. `.表示_描画` corresponde a `表示/描画.zy`, y un
  módulo en la raíz del proyecto se declara sin punto — 囲碁 hace exactamente lo
  mismo en `対局.zy`, que declara `# 対局`. Escribir `# .dibujo` en un
  `dibujo.zy` de raíz produce `E001: Module name '.dibujo' does not match file
  name '_dibujo'`.
- **Conclusión:** `# dibujo` y `# logica` son correctos y se quedan como están. Los
  módulos nuevos que sí viven en subcarpeta (`idioma/despacho.zy`) llevan punto:
  `# .idioma_despacho`.

---

## SRP-I18N-005 · El idioma solo se elegía al arrancar

- **Archivos:** `dibujo.zy`, `idioma/despacho.zy`
- **Descripción:** tras el retrofit el juego era bilingüe, pero elegir idioma
  significaba elegir con qué archivo arrancar: `serpiente.zy` o `snake.zy`. Es el
  punto 9 de la lista de comprobación de
  [USERAPPI18N.md](../interpreter/USERAPPI18N.md), y el que menos se puede dar por
  cubierto con puntos de entrada: quien arranca `serpiente.zy` y no lee español no
  tiene por qué saber que existe el otro archivo. Un selector de idioma sirve
  justamente a quien no entiende el idioma en curso.
- **Solución aplicada (2026-07-26):** `[L]` rota el idioma, tanto en la pantalla de
  velocidad —que es la primera que se ve— como en la de fin de partida, que es donde
  se vuelve entre partida y partida. El marco se reconstruye con el ancho nuevo, así
  que el panel cambia de tamaño con el idioma sin descuadrarse.
- **Lo que costó:** un bug del intérprete. `rotar()` devolvía el idioma nuevo y
  dejaba el estado en el anterior, en el tree-walker y no en la VM. Está en
  [HALLAZGOS_ES.md](HALLAZGOS_ES.md) como **HLZ-SRP-001**, con repro mínimo:
  una función de módulo que escribe estado **y** devuelve un valor con `<~` pierde
  la escritura. El workaround es partirla en dos —una pura que calcula, otra sin
  retorno que escribe— y `pruebas/verificación_idioma.zy` tiene ahora un guardián
  que recorre el ciclo completo de idiomas y comprueba que vuelve al primero.

---

## Lo que **sí** está bien

- **`README_ES.md` existe.** La documentación sí está en dos idiomas; solo el
  programa no lo está.
- **La lógica está separada del dibujo.** `logica.zy` (134 líneas) no contiene ni
  una cadena visible. Todo el trabajo de i18n queda confinado a `dibujo.zy`, que es
  la mejor noticia posible para el retrofit.
- **El juego se adapta al tamaño real de la terminal** (`>>?` en `serpiente.zy`
  L8–L10) y detecta el redimensionado. La maquinaria de posicionamiento dinámico ya
  existe; lo que falta es aplicarla al **ancho del texto**, no solo al del tablero.

---

## Verificación

```bash
bash pruebas/todas.sh          # gate en los dos motores + zymbol check de los 10 módulos
```

Las cuatro pantallas se probaron a mano en una terminal real de 80 × 24 en los dos
idiomas: menú de velocidad, ayuda, pausa y fin de partida, más el marcador durante el
juego. `>>|` se niega a arrancar sin TTY, así que esa parte no es automatizable desde
el runner.

---

## Historial

- **2026-07-26** — Auditoría inicial. Cuatro hallazgos abiertos.
- **2026-07-26** — SRP-I18N-001, 002 y 003 corregidos; SRP-I18N-004 retirado por
  erróneo. El proyecto pasa de v0.0.5 a v0.0.8. `bash pruebas/todas.sh` → `todas PASA`.
- **2026-07-26** — SRP-I18N-005 corregido: el idioma se cambia con `[L]` desde
  dentro del juego. Salió a la luz el bug HLZ-SRP-001 del tree-walker, registrado
  con repro y con guardián en el gate.
