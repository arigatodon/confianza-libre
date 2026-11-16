# Confianza

**Una red de intercambio entre vecinos donde el valor nace del compromiso entre
personas, no del dinero.** Funciona en [confianza.world](https://confianza.world).

Publicas lo que ofreces o necesitas, intercambias con **créditos mutuos** (no es
dinero ni criptomoneda), y después del intercambio las dos partes se evalúan.
Una parte pequeña de cada intercambio va a un **fondo del barrio**, y la
comunidad decide con votaciones en qué se usa. Las reglas de la economía
son públicas y también se cambian con propuestas votadas por la red.

- [Manifiesto](https://confianza.world/manifiesto): por qué existe.
- [Economía](https://confianza.world/economia): las reglas exactas que aplica el sistema.
- [Auditoría del ledger](https://confianza.world/ledger/audit): cualquiera puede verificar que las cuentas cuadran.
- [`ECONOMIA.md`](ECONOMIA.md): la «constitución» económica, con el porqué de cada regla.

## Por qué el código es libre

Creemos que la infraestructura para intercambiar valor debe ser un bien común:
pública, auditable y sin dueño. Si las reglas las decide la comunidad, el código
que las aplica también tiene que estar a la vista. Así nadie, ni siquiera
quienes mantienen el proyecto, puede cambiarlas a escondidas.

Por eso usamos la licencia **[GNU AGPL v3](LICENSE)**: puedes usar, estudiar,
copiar y modificar este código. Si ofreces un servicio basado en una versión
modificada, tienes que publicar tus cambios con la misma licencia. Así lo común
sigue siendo común.

## Cómo está hecho

- Ruby 4.0 · Rails 8.1 · PostgreSQL 16
- Hotwire (Turbo + Stimulus) · Tailwind CSS v4
- Solid Queue / Solid Cable / Solid Cache (sin Redis)
- Contabilidad de **partida doble**: toda transferencia pasa por `CreditTransfer`,
  y en cada transacción la suma de las entradas del ledger da cero.
- App Android: un cascarón con Hotwire Native que navega esta misma web.

## Correrlo en tu computador

Necesitas Ruby 4.0.x (ver `.ruby-version`) y PostgreSQL 16.

```bash
bin/setup          # instala gemas, crea la base y carga datos base
bin/rails demo:seed   # opcional: 10 usuarios de ejemplo con publicaciones
bin/dev            # servidor en http://localhost:3000
```

Tests:

```bash
bin/rails test     # suite completa
bin/ci             # rubocop, auditorías de seguridad, tests y seeds
```

Para tu propio servidor, parte de `config/deploy.example.yml` (Kamal) y de
`.kamal/secrets-common.example`.

## Participar

El proyecto se conversa en español. Puedes abrir un *issue* con ideas, errores o
preguntas, o un *pull request* con cambios. Los cambios a las reglas económicas
se discuten primero, porque afectan a personas reales: empieza leyendo
`ECONOMIA.md`.

Si encuentras una vulnerabilidad, **no la publiques en un issue**. Repórtala en
privado desde la pestaña *Security → Report a vulnerability* de este repositorio.

## Qué hay y qué no hay en este repositorio

Este repositorio es el código que corre en confianza.world. **No contiene datos
de usuarios** ni la configuración privada del servidor (direcciones, claves,
respaldos). Esa información vive aparte y nunca se publica.
