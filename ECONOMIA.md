# Economía de Confianza — Reglas del Crédito

Documento de diseño del sistema económico. Es la **constitución** del sistema: cualquier cambio acá rompe expectativas de usuarios reales. Tocar con cuidado.

Estado: **v0.3** — 2026-11-16: techo común y niveles acotados (ver § 4 y § 9). v0.2 confirmada con Igor el 2026-05-17.

---

## 1. Naturaleza del crédito

Confianza opera un **sistema de crédito mutuo** (mutual credit, tipo LETS / Sardex). Esto significa:

- **No hay respaldo externo.** No es una stablecoin, no convierte a fiat, no es blockchain.
- **No hay emisión central.** Nadie "imprime" créditos.
- **El crédito nace cuando alguien entra en negativo** y muere cuando alguien lo gasta y se quema una parte.
- La unidad se llama por ahora **C** (crédito Confianza). Subdivisión: 1 C = 100 centavos (entero en base de datos).

El sistema en agregado **no se conserva**: la suma de todos los balances de usuarios + fondos territoriales + cuenta de quema **es siempre 0** (partida doble), pero la cuenta de quema crece monotónicamente — esto le da una propiedad deflacionaria si la actividad económica se estanca.

---

## 2. Cuentas (`Account`)

Existen 4 tipos (`account_type`):

| Tipo        | Propietario           | Puede ir negativo | Propósito |
|-------------|-----------------------|-------------------|-----------|
| `user`      | un `User`             | Sí (hasta `-credit_floor`; techo común `credit_ceiling`) | Saldo individual. Una por usuario. |
| `community` | un `Territory`        | No                | Fondo territorial. Acumula impuestos del territorio. Se gasta vía gobernanza. |
| `burn`      | global (1 sola)       | No (sólo crece)   | Lleva contabilidad de lo destruido. Nunca se gasta. |
| `system`    | global                | -                 | Reservado para ajustes administrativos (refunds, correcciones). |

**Reglas:**
- Cada `User` tiene exactamente una `Account` `user` (creada en `after_create_commit`).
- Cada `Territory` tiene exactamente una `Account` `community`.
- Hay una sola `Account` `burn` y una sola `system` globales (creadas en seed).

---

## 3. Estructura de una transacción

Cuando una `Interaction` se cierra con `agreed_credits = T`:

```
T (total)
├── B (burn)        = T × % quema
├── X (territorial) = T × % impuesto territorial
└── R (al receptor) = T − B − X
```

**Ledger entries (4 líneas, partida doble):**

| Cuenta                          | Dirección | Monto |
|---------------------------------|-----------|-------|
| `sender.account`                | debit     | T     |
| `receiver.account`              | credit    | R     |
| `territory.community_account`   | credit    | X     |
| `burn_account`                  | credit    | B     |

`Σ debits = Σ credits = T` ✓ (balance verificable).

**Validación previa:**
- `available_balance = cached_balance + credit_floor` (cuánto puede gastar antes de tocar piso).
- `available_balance ≥ T`.
- `T ≤ tx_cap × category.max_credit_multiplier` (tope por transacción según nivel y categoría).
- `receiver.cached_balance + R ≤ credit_ceiling` (si no, el excedente va al fondo territorial — ver § 4.4).

**Parámetros iniciales (confirmados):**
- `% quema = 2 %`
- `% territorial = 3 %`
- → receptor recibe el **95 %** de lo acordado.

Estos porcentajes son **globales y configurables** (tabla `economic_parameters`). La idea: a futuro la gobernanza global puede votarlos.

---

## 4. Capacidad crediticia (gamificación)

**Principio (v0.3): la confianza te da crédito, no riqueza.**

El sistema **no** maneja un solo "límite". Maneja **dos**:

- `credit_floor` = límite negativo (cuánto puedo "deber" al sistema). Habilita dar antes de tener. **Depende del nivel**: es cuánto me fía la comunidad, y crece con mi trayectoria.
- `credit_ceiling` = límite positivo (cuánto puedo acumular). **Es el mismo para todas las personas** (parámetro global `credit_ceiling`, 5.000 C) y solo cambia por una propuesta global votada por la red. Ningún nivel, reputación ni antigüedad permite acumular más que otra persona.

> **Por qué cambió en v0.3.** En v0.2 el techo subía 10× por nivel (1.000 → 10.000.000 C): quien tenía más reputación podía acumular 10.000 veces más. Eso convertía la reputación en riqueza y contradecía el manifiesto («todos parten de cero», anti-acumulación, «la confianza no se compra»). Un puntaje que decide cuánto puedes tener es justo el mecanismo de control que Confianza quiere evitar. El piso y el tope sí siguen dependiendo del nivel porque son defensas contra el impago y las cuentas falsas, pero en un rango acotado (20×, no 10.000×).

Y un tercer concepto crítico: **Trust Capacity** = el monto máximo permitido **por una sola transacción**, que no es lo mismo que el saldo. Aunque tenga 5.000 C disponibles, si soy nivel 1 no puedo mover 5.000 C en una sola interacción — el sistema limita la *velocidad* de movimiento, no sólo el *stock*.

### 4.1 Niveles base

| Nivel | `credit_floor` | Max por transacción (`tx_cap`) |
|-------|---------------:|-------------------------------:|
| **1** |          −100 |                            50 |
| **2** |          −250 |                           100 |
| **3** |          −500 |                           200 |
| **4** |        −1.000 |                           350 |
| **5** |        −2.000 |                           500 |

Techo (`credit_ceiling`): **5.000 C para todos los niveles** (gobernable, rango seguro 1.000–50.000, solo global). El piso máximo (−2.000) queda siempre por debajo del techo común: nadie puede deber más de lo que cualquiera puede acumular.

Implementación: `CreditLimitCalculator::LEVELS` (piso y tope) y `CreditLimitCalculator.common_ceiling`; `User#credit_ceiling` lee el parámetro en vivo. La columna `users.credit_ceiling` quedó obsoleta (ignorada; se elimina en una migración posterior).

Todos los usuarios nuevos arrancan en **Nivel 1** tras verificar email (antes, Nivel 0 = sólo recibir, sin capacidad de iniciar transacciones).

### 4.2 Cómo se sube de nivel

La progresión depende de la combinación de:

- **Actividad**: número de interacciones completadas (con usuarios distintos).
- **Reputación**: `trust_score` (avg ponderado de reviews recibidas).
- **Cumplimiento**: % de interacciones llevadas a `completed` (no canceladas ni en disputa).
- **Antigüedad**: días desde el registro.
- **Evaluaciones**: cantidad de reviewers distintos que te han evaluado.
- **Categorías**: actividad diversificada (no sólo una categoría).
- **Verificaciones**: `verification_level` (email / phone / identity).
- **Participación territorial**: actividad en el territorio del usuario.

Los umbrales exactos los calibra `CreditLimitCalculator` y se ajustan con datos reales en producción. Para el MVP, una progresión razonable:

| Nivel → | Requisitos mínimos                                                                                       |
|---------|----------------------------------------------------------------------------------------------------------|
| **1**   | Email verificado.                                                                                       |
| **2**   | 3 interacciones completadas, ≥ 2 usuarios distintos, `trust_score` ≥ 3.5, antigüedad ≥ 7 días.          |
| **3**   | 15 interacciones, ≥ 8 usuarios distintos, `trust_score` ≥ 4.0, antigüedad ≥ 30 días.                    |
| **4**   | 50 interacciones, ≥ 25 usuarios distintos, `trust_score` ≥ 4.3, antigüedad ≥ 90 días, phone verificado. |
| **5**   | 200 interacciones, ≥ 100 usuarios distintos, `trust_score` ≥ 4.5, antigüedad ≥ 180 días, identidad verificada. |

El nivel **puede bajar** si el `trust_score` cae o el % de cumplimiento se deteriora.

> **Por qué el Nivel 5 exige 180 días.** La antigüedad crece con el cupo (7 → 30 → 90 → 180) porque cada nivel aumenta el pasivo que la comunidad absorbe ante un impago. Sin un piso temporal en el tope, una granja de cuentas podría inflar 200 interacciones entre 100 cuentas cómplices y saltar al piso máximo en días. (Desde 2026-07 la moderación ya no depende del nivel; desde v0.3 el piso máximo es −2.000.) El tiempo es la defensa más barata contra ataques sibilas.

### 4.3 Multiplicadores por categoría

`Category.max_credit_multiplier` ajusta el `tx_cap` según el tipo de interacción. Las categorías más "sociales" (ayuda, noticia) tienen multiplicador menor — no porque valgan menos, sino porque rara vez justifican movimientos económicos grandes.

| Categoría  | Multiplicador |
|------------|--------------:|
| Noticia    |          0,2 |
| Evento     |          0,5 |
| Ayuda      |          0,7 |
| Servicio   |          1,0 |
| Venta      |          1,2 |
| Delivery   |          1,3 |

**Fórmula del MVP** (validación en `CreditTransfer`):

```
max_allowed = user.tx_cap × category.max_credit_multiplier
agreed_credits ≤ max_allowed                          # tope por transacción
sender.account.cached_balance − agreed_credits ≥ −user.credit_floor
                                                       # no rompe el piso
receiver.account.cached_balance + receiver_amount ≤ user.credit_ceiling
                                                       # no rompe el techo
```

### 4.4 ¿Qué pasa en los límites?

- **Si una transacción haría que el receptor supere el techo común**: el excedente se redirige al fondo territorial. Razón: filosofía anti-acumulación. El receptor no pierde la transacción, pero lo que pasa del techo vuelve a lo común.
- **Si el sender intenta superar `tx_cap` para esa categoría**: el sistema rechaza con mensaje claro ("máximo permitido para tu nivel en esta categoría: X C").
- **Si el sender no tiene capacidad**: rechazo.

### 4.5 Quién decide el monto (UX)

| Actor                  | Rol                                                                  |
|------------------------|----------------------------------------------------------------------|
| Creador de la publicación | **Sugiere** un valor de referencia (campo `Post.suggested_credits`, opcional). |
| Participante           | Acepta el valor sugerido o **contrapropone** al iniciar la interacción. |
| Sistema                | **Valida**: límite del nivel, multiplicador de categoría, comportamiento histórico. |
| Comunidad / datos      | (Fase 2) Contextualiza: rangos típicos por categoría × territorio.   |

El crédito no representa dinero exacto — representa confianza, riesgo, reputación. No buscamos "precio perfecto" sino "credibilidad del intercambio".

### 4.6 No hay transferencias libres

Toda transferencia de créditos requiere la cadena completa:

```
Publicación → Interacción → Transferencia → Evaluación
```

**Nunca** se permite "Usuario A envía N créditos a Usuario B" sin un `Post` y una `Interaction` que lo justifiquen. Esto preserva trazabilidad, reputación y sentido económico — sin esto el sistema se rompe rápido (lavado reputacional, simulación de actividad).

### 4.7 Recálculo

- `after_create_commit` de `Review` → `RecalculateUserTrustJob` (recompone `trust_score`).
- `after_update_commit` de `Interaction` cuando pasa a `completed` → `RecalculateUserLevelJob` (recompone nivel).
- Cron periódico (`DecayInactiveLimitsJob`): si un usuario lleva > 90 días sin reviews positivas y está en zona negativa, `credit_floor` decrece progresivamente.

---

## 5. Territorios y gobernanza

**Definición de territorio (MVP, confirmada 2026-05-17):**

Los territorios son **divisiones administrativas** (país → región → comuna/municipio) obtenidas vía geocodificación inversa de `(post.latitude, post.longitude)`.

**Descubrimiento lazy — no se precargan.** El sistema no viene con un catálogo de comunas. Cada comuna **se desbloquea cuando un primer post o interacción cae allí**. Esto:
- Evita mantener listas estáticas que se desactualizan (cambios administrativos, nombres, etc.).
- Hace que el "mapa de comunidades activas" refleje la actividad real, no una promesa.
- Permite que la app crezca orgánicamente — y narrativamente — a otros países hispanohablantes.

**País inicial: Chile.** El `TerritoryResolver` restringe la creación de territorios al país configurado en `economic_parameters.allowed_countries` (valor inicial: `"CL"`). Cuando llegue el momento de habilitar Argentina/Uruguay/etc., se actualiza el parámetro sin deploy — la lógica ya soporta cualquier país hispanohablante porque depende sólo del código ISO y de Geocoder.

Si un post cae fuera de los países permitidos, la transacción se rechaza con un mensaje claro ("Confianza aún no opera en tu zona — sumate al canal para que tu territorio se habilite").

**Implementación:**
- Tabla `territories` con `country_code`, `admin1` (región/depto/provincia), `admin2` (comuna/municipio), `slug` único.
- Servicio `TerritoryResolver`: dado `(lat, lng)`, devuelve o crea el `Territory` correspondiente. Usa Geocoder (provider configurable; OSM Nominatim al inicio).
- Cache del resultado por `(lat, lng)` redondeado a 3 decimales (~100 m) para evitar geocodificar dos veces lo mismo.
- Fallback: si Geocoder falla, el impuesto va a `system_account` y se reintenta resolver con un job nocturno (`BackfillTerritoriesJob`).

**Asignación del impuesto:**
1. Se toma `(post.latitude, post.longitude)` (no la del sender ni la del receiver — el territorio es donde "ocurre" la publicación).
2. Se busca el `Territory` que contenga ese punto.
3. La porción territorial se credita a `territory.community_account`.

**Gobernanza del fondo territorial:**
- Cualquier usuario con publicaciones/interacciones recientes en ese territorio puede crear una `Proposal` para gastar parte del fondo (ej. "100 C para el evento X").
- Quórum y mayoría a definir (propuesta inicial: 10 votos, 60 % a favor).
- Si pasa: se ejecuta una transacción `community → user` (o `community → otra_community`).
- Voto ponderado por `territory_score` del votante en ese territorio (no sólo trust_score global).

---

## 6. Anti-abuso

- **Auto-interacción ya bloqueada** en modelos (`sender ≠ receiver`, `reviewer ≠ reviewed_user`).
- **Diversidad requerida**: para subir de Nivel 3+ se requieren interacciones con **distintos** usuarios, no inflar con un cómplice.
- **Mínimo de reviewers**: el `trust_score` sólo empieza a contar tras 3 reviewers distintos. Antes vale el default neutral (3.0).
- **Quema mínima** evita microabuso: cada transacción quema al menos `0.01 C` aunque el % dé menos (impide spam de 1-céntimo).
- **Rate limit**: usuario nivel 1 no puede tener más de 5 interacciones abiertas (`requested + accepted + in_progress`) simultáneamente.
- **Decay del límite**: si un usuario lleva > 90 días sin reviews positivas nuevas y está en negativo, su `credit_floor` decrece (no se condona la deuda, pero se le impide profundizarla).
- **No transferencias libres**: la cadena `Post → Interaction → Transferencia → Review` es obligatoria (ver § 4.6).
- **Disputas** (`Interaction.status = disputed`) congelan el ledger entry pendiente hasta resolución.

---

## 7. Esquema de DB — cambios necesarios

Hoy el modelo `Account`, `Transaction`, `LedgerEntry` ya existen pero les faltan campos. Cambios:

**`accounts`:**
- `+ territory_id` (nullable, sólo para `account_type = community`).
- Validación: `account_type = user` ⇒ `user_id` presente y `territory_id` nulo. `account_type = community` ⇒ al revés.
- Validación: `cached_balance ≥ -credit_floor` y `cached_balance ≤ credit_ceiling` (sólo para `user`).

**`users`** (reemplaza `credit_limit` actual, que es un único valor):
- `+ credit_floor` (integer, default 0)
- `+ credit_ceiling` (integer, default 0)
- `+ tx_cap` (integer, default 0)
- `+ level` (integer, default 1)
- (mantener `trust_score`, `verification_level` ya existentes)

**`categories`** (ya tienen `trust_weight`, `allows_credit`, `max_credit_multiplier`):
- Confirmar que el seed inicial cargue los multiplicadores del § 4.3.

**`posts`:**
- `+ suggested_credits` (integer, nullable) — el creador puede proponer un valor de referencia.

**`transactions`:**
- `+ territory_id` (snapshot de a qué territorio fue el impuesto — auditable).
- `+ category_id` (snapshot de la categoría usada para validar el multiplicador).

**Tablas nuevas:**
- `territories` (id, name, slug, country_code, admin1, admin2, lat/lng del centroide, source = 'admin'|'custom'|'system').
- `economic_parameters` (key, value, updated_at, updated_by) — para `burn_percent`, `territory_percent` y otros parámetros globales editables sin deploy.

---

## 8. UX (en grandes trazos)

1. **Crear una transacción**:
   - El **creador del post** sugiere un valor de referencia (campo `Post.suggested_credits`, opcional).
   - El **participante** acepta el sugerido o contrapropone al iniciar la interacción.
   - El sistema valida tope (`tx_cap × multiplicador`), piso y techo en vivo (feedback antes de enviar).
   - Al cerrar la interacción (status `completed`, ambos confirmaron), la transacción se ejecuta automáticamente.
2. **Wallet** (`/billetera`):
   - Balance disponible (`cached_balance + credit_floor`) y balance neto.
   - Indicador del nivel actual con piso, techo y `tx_cap`.
   - Próximo nivel y qué falta para alcanzarlo (barra de progreso multicriterio: interacciones, usuarios distintos, trust_score, antigüedad).
   - Multiplicadores efectivos por categoría (cuánto puedo mover en una sola tx según la categoría).
   - Historial: ingresos (verde), egresos (gris), quema (rojo claro), territorial (azul).
3. **Fondo territorial** (`/territorios/:slug`):
   - Total acumulado, transacciones recientes, propuestas abiertas, propuestas históricas.

---

## 9. Decisiones cerradas (2026-05-17)

| Pregunta              | Decisión                                                                |
|-----------------------|-------------------------------------------------------------------------|
| % quema / territorial | 2 % quema + 3 % territorial (receptor 95 %).                            |
| Quién decide el monto | Creador sugiere → participante negocia → sistema valida (ver § 4.5).    |
| Territorios MVP       | Divisiones administrativas vía geocodificación. Sin polígonos custom.   |
| Tabla de niveles      | Nueva tabla §4.1 con piso/techo/tx_cap por nivel (rango 100 → 10 M C). **Reemplazada en v0.3.** |

## 9b. Decisiones v0.3 (2026-11-16, Igor)

| Pregunta | Decisión |
|----------|----------|
| ¿El nivel da más capacidad de acumular? | **No.** Techo común `credit_ceiling` = 5.000 C para todos, gobernable solo por propuesta global. |
| Rango de piso y tope por nivel | Acotado a 20×: piso −100 → −2.000, tope 50 → 500. |
| ¿Quién puede proponer cambios de reglas? | Cualquiera desde nivel 1 (`proposal_rules_min_level` = 1, ahora gobernable). El quórum y la mayoría filtran. |
| Migración | `20261116120000_techo_comun_y_niveles_acotados` recalcula piso y tope de todos los usuarios según su nivel (incluye bonus de padrinazgo). |

## 10. Ideas para Fase 2 / 3

- **Precio recomendado por IA / comunidad**: el sistema aprende de transacciones históricas — "los deliveries en Cartagena suelen costar 40–120 C" — y muestra ese rango al sender/receptor en el form. Evita inflación absurda y precios irreales.
- **Voto del fondo territorial ponderado por `territory_score`** (no `trust_score` global) — quien más actuó en un territorio tiene más voz para decidir cómo se usa su fondo.
- **Categorías permitiendo o no crédito** (`Category.allows_credit`): en categorías muy comerciales (venta de bienes caros) puede requerirse saldo positivo, sin opción de ir negativo.
- **Penalización por defecto**: si un usuario queda en negativo > N días sin nueva actividad positiva, su `tx_cap` se reduce automáticamente.
- **Auditoría pública del ledger**: dado que la partida doble es verificable, exponer un endpoint `/ledger/audit` que cualquiera pueda consultar para verificar que el sistema balancea.

---

## 11. Roadmap de implementación

Cada paso es 1–2 PRs. El orden está pensado para no romper nada: hasta que `CreditTransfer` esté listo, las interacciones siguen completándose sin generar ledger.

1. **Migraciones de schema** (sin lógica todavía):
   - Tabla `territories` (id, name, slug, country_code, admin1, admin2, lat, lng, source).
   - Tabla `economic_parameters` (key, value, updated_at).
   - `accounts.territory_id`, validaciones de tipo.
   - `users`: reemplazar `credit_limit` por `credit_floor`, `credit_ceiling`, `tx_cap`, `level`.
   - `posts.suggested_credits`.
   - `transactions.territory_id`, `transactions.category_id`.
2. **Seed inicial** (sin territorios — éstos se crean lazy):
   - `Account` `burn` global, `Account` `system` global.
   - `economic_parameters`: `burn_percent = 2`, `territory_percent = 3`, `allowed_countries = "CL"`.
   - Categorías con multiplicadores del § 4.3.
3. **Callback `User.after_create_commit`** → crea `Account` `user` con saldo 0 y límites del Nivel 1.
4. **Servicio `TerritoryResolver`**: dado `(lat, lng)`, devuelve/crea el `Territory` correspondiente (Geocoder + cache).
5. **Servicio `CreditTransfer`** (`app/services/credit_transfer.rb`):
   - Input: `interaction`, `total_amount`.
   - Carga `burn_percent` y `territory_percent` desde `economic_parameters`.
   - Resuelve territorio con `TerritoryResolver` (asegura `Account` community del territorio).
   - Valida tope: `tx_cap × category.max_credit_multiplier`.
   - Valida piso del sender y techo del receiver.
   - Crea `Transaction` + 4 `LedgerEntry` en una `ActiveRecord::Base.transaction`.
   - Marca `Transaction.completed`, dispara validación `ledger_must_balance`.
   - Actualiza `cached_balance` de las cuentas tocadas.
6. **Servicio `TrustScoreCalculator`** + Job `RecalculateUserTrustJob`.
7. **Servicio `CreditLimitCalculator`** que aplica la tabla del § 4.1 + Job `RecalculateUserLevelJob`.
8. **Hooks**:
   - `Review.after_create_commit` → `RecalculateUserTrustJob`.
   - `Interaction.after_update_commit` (cuando `status` cambia a `completed`) → `CreditTransfer` (si `agreed_credits > 0`) + `RecalculateUserLevelJob`.
9. **Cron `DecayInactiveLimitsJob`** (recurring en Solid Queue).
10. **Vistas**:
    - `/billetera`: balance + historial + progreso de nivel + `tx_cap` por categoría.
    - `/territorios/:slug`: fondo acumulado + propuestas abiertas + historial.
    - Pantalla de cierre de interacción: desglose previo (al receptor / fondo / quema) antes de confirmar.
11. **Propuestas**: vista de creación + lista + voto en `/territorios/:slug`.
12. **Endpoint público `/ledger/audit`** (Fase 2): exposición auditable del balance del sistema.
