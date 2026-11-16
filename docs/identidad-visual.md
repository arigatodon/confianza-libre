# Identidad visual — "Señal de barrio"

## Concepto

Confianza es infraestructura del barrio, no un nicho alternativo ni una fintech.
La identidad toma prestado el lenguaje de lo público que funciona: la
**señalética del transporte** (placas de color plano, letra clara, una línea de
color por recorrido), el **toldo azul de la feria libre** y el **almacén de la
esquina**, donde el fiado siempre fue crédito entre vecinos. Debe leerse igual
de bien en un celular de gama media al sol que en un computador, y sentirse de
todos: ni de una empresa ni de una tribu.

Por eso: azul de toldo como color principal (confiable sin ser bancario),
papel y tinta como neutros (sin crema "orgánico"), y un solo acento cálido, el
**amarillo señal**, reservado para lo común: el punto de la marca, el fondo del
barrio, los rótulos de "Ejemplo" y las llamadas a sumarse. Nada de degradados,
neón ni brillo de cripto: el manifiesto rechaza la especulación y la interfaz
también.

La marca son **dos mitades iguales frente a frente y un punto al centro**: las
dos partes de cada intercambio, en igualdad, alrededor de lo que comparten (el
territorio, el fondo, la confianza). Visto desde arriba también es una plaza, y
en el mapa es el "usted está aquí".

## Paleta (tokens en `app/assets/tailwind/application.css`)

Se mantienen los nombres de token tipo Material que ya usan las vistas; cambian
los valores. Contrastes medidos con WCAG 2.1.

| Token | Valor | Uso |
|---|---|---|
| `primary` | `#1f56a8` azul toldo | Botones, enlaces, franja superior, línea de "servicio". Blanco encima 7,1:1 |
| `primary-strong` | `#17427f` | Hover/presionado del primario |
| `primary-container` | `#15396d` azul noche | Pie, bandas oscuras, títulos destacados |
| `primary-fixed` | `#dde7f6` | Fondos suaves informativos (avisos, avatares) |
| `signal` | `#ffc629` amarillo señal | Punto de marca, fondo comunitario, "Ejemplo", CTA de registro. **Siempre con tinta encima**, nunca como texto |
| `secondary` | `#8a5a00` ámbar | Línea de venta/delivery, estrellas, avisos. Texto sobre blanco 5,9:1 |
| `secondary-container` | `#ffc629` | Fondo amarillo (= signal) |
| `tertiary` | `#0e6e55` verde paradero | Línea de ayuda, paso "Evalúa" |
| `linea-violeta` | `#6b3fa0` | Línea de eventos, propuestas y noticias |
| `ink` / `on-surface` | `#15181c` tinta | Texto principal (16:1 sobre papel) |
| `on-surface-variant` | `#4a4f57` | Texto secundario (7,5:1 sobre papel) |
| `paper` / `background` | `#f5f4f0` papel | Fondo general |
| `surface-container-lowest` | `#ffffff` | Tarjetas ("placas") y campos |
| `surface-container-low…highest` | `#efeee9` → `#dad9d2` | Fondos de sección y chips |
| `outline` | `#6e737b` | Borde de campos y controles (≥ 3:1) |
| `outline-variant` | `#b4b7b9` | Divisores y bordes de tarjeta (decorativo) |
| `error` | `#b3261e` | Errores y saldos negativos |

**Líneas de color por tipo de publicación** (`PostsHelper::LINEAS`): ámbar =
venta y delivery · azul = servicio · verde = ayuda · violeta = evento,
propuesta, noticia · azul noche = blog. Van en el borde superior de la
tarjeta y en la placa del tipo.

**Modo oscuro:** la app no tiene modo oscuro; no se definió.

**Alias heredados** (`organic-green-deep`, `earth-clay`, `soft-sky`,
`warm-surface`): apuntan a los valores nuevos y solo siguen en `manifesto`,
`economics/show` y `wallet/show`, que se estaban reescribiendo en paralelo.
Al migrar esas vistas: `organic-green-deep → primary-strong`,
`earth-clay → secondary`, `soft-sky → primary-fixed`,
`warm-surface → surface-container-lowest`, y borrar los alias.

## Tipografía

- **Overpass** (títulos, cifras, rótulos y logo): heredera abierta de la letra
  de la señalética vial. Pesos 700–800.
- **Public Sans** (texto e interfaz): diseñada para servicios públicos
  digitales, muy legible en tamaños chicos. Pesos 400–700.
- Autoalojadas en `app/assets/fonts/` (variables, subconjunto latino, ~66 KB
  las dos), `font-display: swap`, precargadas en `shared/_fuentes`. Licencia
  OFL junto a cada archivo.
- Escala (`@utility`, funcionan con `md:`): `text-headline-xl` 46,
  `text-headline-lg` 34, `text-headline-lg-mobile` 29, `text-headline-md` 22,
  `text-headline-sm` 19, `text-body-lg` 18, `text-body-md` 16,
  `text-label-md` 15, `text-caption` 13.
- `text-rotulo`: mayúsculas cortas con aire (12 px, Overpass 700, +8 %
  espaciado) para secciones y placas. Las etiquetas existentes en mayúsculas
  (`text-caption uppercase`) toman este estilo solas.
- `cifra`: saldos y contadores en Overpass 800 con números tabulares.

## Iconografía

- Material Symbols Outlined, **peso 500** (pictograma firme), relleno solo para
  estado activo o énfasis (`icon-filled`).
- Subconjunto autoalojado (`app/assets/fonts/material-symbols-outlined.woff2`,
  ~40 KB en vez de ~4 MB). **Al usar un ícono nuevo: `bin/rails iconos:subset`.**
  `test/helpers/iconos_test.rb` falla si una vista usa un ícono que no está.
- Íconos sobre placa de color (cuadrado redondeado `rounded-lg`) cuando el
  ícono identifica algo (tipo de publicación, paso, señal en el mapa).

## Forma

- **Placas, no burbujas:** tarjetas blancas con borde fino (`outline-variant`),
  radio 14 px (`rounded-xl`), sombra corta y neutra (`ambient-shadow`).
- **Línea de color** de 4 px en el borde superior para indicar tipo o sección
  (como el color de una línea de micro o metro). El amarillo de 6 px es solo
  para lo común (fondo del territorio).
- Botones en píldora (`rounded-full`), alto mínimo 44 px (`min-h-11`), primarios
  en azul; el amarillo con tinta se usa para "Crear cuenta"/"Regístrate".
- **Franja azul** (`.franja`): barra superior móvil (igual a `theme-color`),
  bandas de llamado a la acción. El foco dentro de la franja se marca en
  amarillo (`.franja`, `.foco-claro`).
- Ítem activo de navegación: texto azul + línea azul (arriba en la barra
  inferior, a la izquierda en la lateral).

## Logo y archivos

| Archivo | Uso |
|---|---|
| `app/assets/images/confianza-marca.svg` | Marca sola en placa azul (avatar de redes, ícono) |
| `app/assets/images/confianza-logo.svg` | Logo horizontal sobre fondo claro |
| `app/assets/images/confianza-logo-negativo.svg` | Logo sobre azul (sin placa, letra blanca) |
| `app/views/shared/_marca.html.erb`, `_logo.html.erb` | Marca y logo inline en las vistas |
| `public/icon.svg`, `favicon.ico`, `icon.png` | Favicon y PWA |
| `public/icon-maskable.png`, `apple-touch-icon.png` | Íconos a sangre (Android, iOS) |
| `public/og-default.png` | Imagen al compartir enlaces |

El texto del logo es "Confianza" en Overpass ExtraBold (en los SVG va
convertido a trazos). Espacio libre alrededor: el ancho de una mitad de la
marca. Tamaño mínimo de la marca: 16 px.

## Reglas de uso

1. Azul para actuar, amarillo para lo común, tinta para leer. No más de un
   amarillo protagonista por pantalla.
2. Nada de gente ni actividad inventada en páginas públicas: si se muestra
   algo ilustrativo, va rotulado **Ejemplo** (placa `text-rotulo` sobre
   amarillo o gris) y sin fotos de personas.
3. Sin fotos de stock ni degradados de fondo; ilustraciones planas con la
   paleta (ver `home/_plano_barrio`).
4. Contraste AA mínimo; el amarillo y el `outline-variant` nunca como texto.
5. Objetivos táctiles ≥ 44 px y nada que desborde a 360 px de ancho.
6. Colores nuevos van como token en `@theme`; no escribir hex en las vistas
   (excepciones: correos, que no leen CSS externo, y las tarjetas PNG de
   `Difusion::Tarjeta` y `Vitrina::TarjetaQr`).

## Cómo escribimos

La meta: que una persona de 12 años entienda cómo usar Confianza.

1. **Cada pantalla responde dos preguntas:** «¿qué es esto?» y «¿qué puedo
   hacer ahora?». Una acción principal por pantalla, bien visible (botón
   azul, `min-h-12`). En un intercambio, la tarjeta **Ahora** dice qué pasa y
   qué te toca.
2. **Palabras antes que números.** Si hace falta un número, va uno solo y con
   etiqueta simple: «Tienes 28 C». Nada de rangos (−100 / +5.000), decimales
   (3,00 / 5), porcentajes, fórmulas ni tablas en la vista principal. Las
   estrellas se dibujan (`estrellas(valor)`) y se dicen en palabras
   (`estrellas_en_palabras`). Créditos siempre con `creditos(n)` (espacio duro
   entre el número y la C) y conteos con `contar(n, "intercambio")`.
3. **Sin jerga** (tabla abajo). Tuteo chileno: «tú», no «vos».
4. **Frases cortas:** una o dos a la vista, de menos de ~15 palabras. El resto
   va detrás de «¿Cómo funciona?» (`details`/`summary`) o de un enlace a
   `/economia`. Menos es más.
5. **El progreso es una lista de pasos en palabras:** «Para subir al Nivel 2:
   ✓ Verificaste tu email · Cierra 2 intercambios más · Espera 6 días más»
   (`pasos_para_subir`). Nunca «1 / 3».
6. **Íconos siempre con texto.** Se diseña primero para el celular.
7. **La transparencia no se pierde, se ordena en capas:** arriba un resumen en
   frases; las tablas y los parámetros exactos, leídos de las fuentes vivas,
   dentro de «Ver las reglas exactas» (`/economia`).

| En vez de… | Decimos… |
|---|---|
| trust score | reputación, estrellas |
| tope, tx_cap, máximo por transacción | lo máximo por intercambio |
| piso, credit floor | lo que la comunidad te fía |
| techo, credit ceiling | lo máximo que alguien puede juntar (igual para todos) |
| L1, L2… | Nivel 1, Nivel 2… |
| quema, burn | una parte pequeña se borra, para que los créditos no pierdan valor |
| ledger, cached, balance | saldo, movimientos |
| interacción | intercambio |
| contraparte | persona |
| disputa (como acción) | ¿Hubo un problema? / avisar del problema |
| beneficiario | para (quién) |
| quórum, mayoría requerida | faltan N votos · se aprueba si 6 de cada 10 votan a favor |
| territorio (en textos) | barrio |
