# Roadmap 10x — Confianza

Actualizado: 2026-07-02. Complementa a [`ROADMAP.md`](ROADMAP.md) (el roadmap
comunitario corto). Este documento es el plan de producto detallado: qué
construir para que la red valga 10 veces más, en qué orden, y **cómo sabemos
que cada cosa está terminada** (criterios de aceptación verificables).

---

## 1. Diagnóstico — qué hay y qué está roto

### Lo que ya funciona (y es mucho)

MVP completo en producción (confianza.world): perfiles, posts georreferenciados,
interacciones con negociación y doble confirmación, doble review, economía de
partida doble con niveles/decay/quema/fondo territorial, gobernanza con quórum
escalonado, moderación con recompensa, mensajes directos, push web, aval
comunitario, difusión a redes (Telegram/Bluesky/IG/FB), app Android Hotwire
Native (APK debug), backups + monitoreo, SEO + invitaciones.

### Promesas rotas (el código contradice la visión)

| # | Problema | Evidencia | Impacto |
|---|----------|-----------|---------|
| P1 | **Disputas sin salida**: se puede abrir (`interactions#dispute`) pero no existe resolución. El crédito queda congelado para siempre. | `app/controllers/interactions_controller.rb:75`; `ModerationController` solo opera sobre `Report` | Rompe la confianza — el caso donde MÁS se necesita la plataforma es el peor atendido |
| P2 | **Nivel 5 inalcanzable**: nada setea `verification_level: identity`. Nivel 4 solo vía avales. | `CreditLimitCalculator::REQUIREMENTS` exige `identity`; grep sin controller/servicio que lo otorgue | La progresión promete algo que no existe; logro `identity_verified` imposible |
| P3 | **"Reglas locales" son globales**: un `rule_change` votado en una comuna hace upsert global de `EconomicParameter`. | `economic_parameter.rb` sin `territory_id`; `ProposalExecutor#execute_rule_change` | Contradice el manifiesto — la gobernanza territorial de reglas es de facto global |
| P4 | **Moderación acoplada al nivel económico**: `moderator? = level >= 3`. | `app/models/user.rb` | Quien acumula crédito gana poder de policía; vector de abuso |

### Débil (funciona pero no escala ni retiene)

| # | Problema | Evidencia |
|---|----------|-----------|
| D1 | Feed = distancia + cronológico, límite duro 20, sin paginación, sin ranking | `home_controller.rb#load_feed` |
| D2 | Búsqueda = `LIKE '%q%'` sin índice; `pg_search` en Gemfile **sin usar** | `post.rb:77`, `people_controller.rb:12` |
| D3 | PostGIS nunca habilitado: floats + Haversine de Geocoder | `db/schema.rb` (solo plpgsql) |
| D4 | Jobs sin `retry_on`; decay job hace full scan diario de users | `application_job.rb`, `decay_inactive_limits_job.rb` |
| D5 | Cache de `EconomicParameter` por proceso — tras un `rule_change`, otros procesos Puma sirven el valor viejo | `economic_parameter.rb` |
| D6 | Modelos críticos casi sin tests unitarios: `Account`, `LedgerEntry`, `User` (placeholders de 7 líneas) | `test/models/` |
| D7 | `CreditTransaction` tiene estados `reversed/failed` que ningún flujo usa (no hay reversa) | `credit_transaction.rb` |
| D8 | `Territory#active_members_count` y stats de territorio: pluck + uniq en Ruby por request, sin cache | `territory.rb:26` |
| D9 | Reporte de `DirectMessage` no paga reward (falta en el `case` del resolver) y `Notification#link_path` no resuelve `Report` | `report_resolver.rb`, `notification.rb` |

---

## 2. Tesis 10x

El valor de Confianza = **confianza en la que puedes apoyarte** × **facilidad de
encontrar el intercambio que necesitas** × **gente activa cerca tuyo**.

Hoy la plataforma es un marketplace pasivo: publicas y esperas. El salto 10x
viene de cuatro palancas, en este orden:

1. **Cerrar los ciclos de confianza** — si una disputa muere en un callejón sin
   salida, la primera mala experiencia mata al usuario y a su círculo. (P1–P4)
2. **Liquidez: que la red te encuentre el match** — pasar de "publico y espero"
   a "la red me avisa cuando alguien cerca necesita lo que ofrezco". (D1, D2)
3. **Economía territorial real** — la promesa diferencial del manifiesto:
   reglas y presupuesto por comuna. Nadie más ofrece esto. (P3)
4. **Distribución móvil** — Play Store + push nativo. La red es móvil o no es.

Las fundaciones técnicas (D3–D9) se reparten dentro de las fases como
prerequisitos, no como fase aparte que nunca llega.

---

## 3. Fase 1 — Cerrar los ciclos de confianza (1–2 semanas)

### 1.1 Sistema de disputas completo ⚠️ la deuda más grave

Flujo: cualquiera de las partes abre disputa con argumento escrito → la otra
parte responde → un moderador (que no sea parte) resuelve con uno de tres
veredictos: completar (transfiere crédito), cancelar (no transfiere), o
completar parcial (monto ajustado). Todo queda en el timeline de la interacción.

**Implementación**: modelo `Dispute` (interaction, opener, argument, status:
`open/responded/resolved`, verdict, resolved_by, resolution_note) + panel en
`/moderacion` (pestaña Disputas) + `DisputeResolver` service que reutiliza
`CreditTransfer` para el veredicto "completar". El chat de la interacción
permanece abierto durante la disputa (ya es así).

**Criterios de aceptación**
- [ ] Abrir disputa exige un argumento de ≥ 30 caracteres; la otra parte recibe notificación + email y puede responder una vez.
- [ ] Un moderador L3+ que NO es parte de la interacción ve la disputa en `/moderacion` con ambos argumentos y el chat completo.
- [ ] Veredicto "completar": dispara `CreditTransfer` con el monto original (o ajustado); la interacción pasa a `completed`; ambas partes pueden dejar review.
- [ ] Veredicto "cancelar": la interacción pasa a `canceled`; no se mueve crédito; se notifica a ambas partes con la nota de resolución.
- [ ] Las partes de la disputa nunca pueden resolverla, ni un moderador puede resolver una disputa propia (test de autorización).
- [ ] Una interacción `disputed` sin resolver ≥ N días (parámetro `dispute_auto_escalate_days`, default 7) aparece destacada en el panel.
- [ ] Suite: ≥ 10 tests nuevos (modelo + resolver + controller + autorización). `bin/rails test` verde.
- [ ] Novedad publicada en `/novedades` explicando el flujo en lenguaje simple.

### 1.2 Verificación de identidad (desbloquea L5)

Camino coherente con el proyecto (sin SMS pago, decidido en consulta): **aval
reforzado presencial** — N usuarios ya verificados-identity o moderadores
confirman haber verificado el documento en persona, O subida de documento con
revisión por moderador. Empezar por la segunda (más simple de operar con red
chica) y dejar la primera como propuesta de gobernanza.

**Implementación**: modelo `IdentityVerification` (user, imagen ActiveStorage,
status `pending/approved/rejected`, reviewed_by, note) + form en `/settings` +
cola de revisión en `/moderacion`.

**Criterios de aceptación** — ✅ DEPLOYADA 2026-07-04 (vía subida de documento)
- [x] Un usuario con email verificado puede subir 1–2 imágenes de documento desde `/settings`; ve el estado de su solicitud.
- [x] Aprobación por moderador sube `verification_level` a `identity` y dispara `RecalculateUserLevelJob`; rechazo notifica con motivo y permite reintentar.
- [x] Las imágenes del documento solo son visibles para moderadores L3+ (streaming autorizado en `ModerationController`, nunca por URL pública; test de autorización).
- [x] Las imágenes se purgan automáticamente ≤ 30 días después de aprobar/rechazar (`PurgeIdentityDocumentsJob`, diario en recurring.yml).
- [x] Con identity aprobada + demás requisitos, `CreditLimitCalculator` otorga L5 (test end-to-end del camino completo a nivel 5).
- [x] El logro `identity_verified` se desbloquea (ya estaba mapeado a vlevel≥3 en `AchievementCatalog`).

_Falta (queda como propuesta de gobernanza, según el plan): el camino de "aval
reforzado presencial" para verificar identidad sin documento._

### 1.3 Rol de moderación desacoplado del nivel

`moderator?` deja de ser `level >= 3` y pasa a un flag `moderator_since`
otorgable/revocable. Bootstrap: los L3+ actuales lo reciben en la migración.
Nuevos moderadores: por propuesta de gobernanza kind `grant_moderation`
(reutiliza `Proposal` + `ProposalExecutor`).

**Criterios de aceptación** — ✅ DEPLOYADA 2026-07-04
- [x] Subir de nivel económico ya no otorga moderación; los moderadores existentes la conservan (bootstrap en la migración: L3+ o admin; test de decoupling).
- [x] Una propuesta `grant_moderation` aprobada otorga el rol; una `revoke_moderation` lo quita; ambas con el quórum escalonado existente.
- [x] Todos los gates (`/moderacion`, resolver reportes, avalar, resolver disputas, revisar identidad) usan `moderator?` (flag) — grep sin `level >= 3` para autorización.

### 1.4 Fundaciones de integridad (van en esta fase porque protegen el ledger)

**Criterios de aceptación**
- [ ] `ApplicationJob` con `retry_on` (deadlock, timeouts de red) y `discard_on` (`ActiveRecord::RecordNotFound`); `PushNotificationJob` reintenta 3 veces con backoff.
- [ ] `DecayInactiveLimitsJob` filtra candidatos en SQL (sin full scan; test que verifica el scope).
- [ ] Cache de `EconomicParameter` movido a `Rails.cache` (Solid Cache, compartido entre procesos) con TTL corto; tras un `rule_change` ejecutado, un segundo proceso lee el valor nuevo en ≤ 60 s.
- [ ] Tests unitarios reales para `Account`, `LedgerEntry` y `User` (mínimo: unicidad de cuentas, `ledger_must_balance`, `available_balance`, transiciones de `verification_level`).
- [ ] `credit:reconcile` corre semanal por Solid Queue cron y alerta por email si algún `cached_balance` difiere del ledger.
- [ ] Reportar un `DirectMessage` paga reward y `Notification#link_path` resuelve reportes (fix D9).

---

## 4. Fase 2 — Liquidez: la red te encuentra el match (2–4 semanas)

### 2.1 Búsqueda real (prerequisito de todo lo demás) ✅ DEPLOYADA 2026-07-04

Activar `pg_search` (ya está en el Gemfile) con tsvector en español + `unaccent`
+ trigram para tolerancia a typos, sobre posts y personas.

**Criterios de aceptación**
- [x] Buscar "gasfiter" encuentra posts con "gásfiter" y "gasfitería" (unaccent + stemming español). — config `spanish_unaccent` + `prefix`.
- [x] Resultados ordenados por relevancia (`ts_rank`) y luego distancia; los filtros existentes (categoría, kind, radio, créditos) siguen componiendo.
- [x] Extensiones `pg_trgm` + `unaccent` en migración; índices GIN sobre el tsvector (verificable con `EXPLAIN`: no seq scan por texto). — schema pasó a `structure.sql`.
- [x] `/vecinos` usa la misma búsqueda para username/bio (+ headline).
- [x] Búsqueda con 0 resultados ofrece "crear una publicación pidiendo esto" (puente a 2.2), con el título prellenado.

_Nota: los índices trigram (`pg_trgm`) quedaron creados sobre título y username;
falta explotarlos en la query para typos duros (hoy la tolerancia viene del
stemming + prefix). Se retoma si aparece necesidad real._

### 2.2 Pedidos + matching automático — **la feature 10x**

Hoy solo existe "ofrezco". Falta la otra mitad del mercado: **"busco/necesito"**
(kind `pedido`). Con ambas mitades, la red hace el trabajo: cuando aparece un
pedido cerca de alguien que ofrece esa categoría (o viceversa), se le avisa.

**Implementación**: flag `pedido` en `Post` (booleano ofrezco/busco, ortogonal
a la categoría, en vez de un `kind` para no romper la inferencia categoría→kind)
+ `MatchFinder` service (candidatos por categoría + radio + status published) +
`MatchNotificationJob` al publicar + preferencias de aviso por usuario
(`match_notifications`, `match_radius_km`, `match_category_ids`).

**Criterios de aceptación** — ✅ DEPLOYADA 2026-07-04
- [x] Publicar un pedido notifica (push + in-app) a usuarios en el radio con posts publicados de esa categoría, excluyendo al autor; máx. 1 notificación por usuario por pedido.
- [x] Publicar una oferta notifica a autores de pedidos abiertos compatibles cerca.
- [x] El usuario controla en `/settings` qué categorías y radio le generan avisos de match; opt-out total posible.
- [x] Desde la notificación de match se llega en 1 tap al post (`link_path`/push `data.path`) y desde el post a iniciar interacción o mensaje directo.
- [x] Anti-spam: throttle de máx. N avisos de match por usuario por día (parámetro gobernable `match_daily_cap`, default 5).
- [x] El feed y `/explore` permiten filtrar por "pedidos" vs "ofertas".
- [x] Métrica registrada: `bin/rails metrics:pedidos_match` (% de pedidos con ≥1 interacción en 72 h).

_Nota de escala: `MatchFinder` carga los posts cercanos y filtra el radio por
candidato en Ruby (radio personal por usuario). Correcto para la red actual;
si crece, mover el filtro de radio a SQL/PostGIS (2.5)._

### 2.3 Alertas guardadas

Una búsqueda en `/explore` se puede guardar como alerta: "avísame cuando
aparezca algo así por acá".

**Criterios de aceptación** — ✅ DEPLOYADA 2026-07-04
- [x] Guardar la búsqueda actual (texto + filtros + radio) con 1 click; listado y borrado en `/settings`.
- [x] Un post nuevo que matchea una alerta notifica al dueño (push + in-app), respetando el throttle diario global (compartido con los match de 2.2).
- [x] Máx. 10 alertas por usuario; evaluación por `SavedSearchAlertJob` al publicar (no cron), con test de que un post fuera de radio NO notifica.

### 2.4 Feed rankeado con paginación

**Criterios de aceptación**
- [ ] Feed pagina (infinite scroll con Turbo, 20 por página); desaparece el techo duro de 20.
- [ ] Ranking = combinación de cercanía + recencia + trust del autor + engagement (comentarios/interacciones), con pesos en `EconomicParameter` (ajustables sin deploy).
- [ ] Pedidos activos cercanos se intercalan destacados en el feed.
- [ ] Sin coordenadas el feed sigue funcionando (fallback cronológico, test).
- [ ] Sin N+1 nuevos (verificado con `strict_loading` o bullet en dev sobre el feed).

### 2.5 PostGIS de verdad (fundación de esta fase)

**Criterios de aceptación**
- [ ] Extensión PostGIS habilitada en prod y dev; columnas `geography(Point)` pobladas desde los floats existentes (migración con backfill, floats se mantienen hasta validar).
- [ ] `Post.near` / queries de radio usan `ST_DWithin` con índice GiST (verificable con `EXPLAIN`).
- [ ] El mapa de `/explore` agrupa clusters server-side cuando hay > 200 puntos en viewport.
- [ ] `TerritoryResolver` puede resolver por polígono si el territorio tiene geometría (fallback al geocoder actual si no).

---

## 5. Fase 3 — Economía territorial real (4–8 semanas)

### 3.1 Parámetros económicos por territorio (cumplir P3)

`EconomicParameter` gana `territory_id` opcional: NULL = global, con valor =
override local. Lectura: `EconomicParameter.get(key, territory:)` con fallback
a global. `rule_change` votado en un territorio escribe el override local; solo
una propuesta global (quórum de toda la red) toca el valor global.

**Criterios de aceptación** — ✅ DEPLOYADA 2026-07-04
- [x] `CreditTransfer` usa burn/territory percent del territorio de la transacción; dos comunas con overrides distintos queman distinto (test con 2 territorios).
- [x] Un `rule_change` aprobado en la comuna A no afecta a la comuna B ni al global (test de aislamiento); local por defecto, checkbox "aplicar a toda la red" para el global.
- [x] `/economia` y `/territorios/:slug` muestran qué reglas son locales vs heredadas del global.
- [x] Rangos min/max de `GOVERNABLE_PARAMETERS` se siguen aplicando a los overrides.
- [x] Migración sin downtime: índice único (key, territory_id) NULLS NOT DISTINCT; los parámetros globales existentes (territory_id NULL) siguen valiendo tal cual.

_Refinamiento pendiente: el quórum de un `rule_change` local hoy sigue siendo el
de red; idealmente escalaría con los miembros activos del territorio._

### 3.2 Panel económico del territorio

**Criterios de aceptación**
- [ ] `/territorios/:slug` muestra: fondo actual, ingresos/egresos del fondo por mes, transacciones y volumen por semana, miembros activos, top categorías — todo desde el ledger (sin contadores paralelos).
- [ ] Stats cacheadas (Solid Cache, TTL ≥ 1 h); el `pluck+uniq` en Ruby de `active_members_count` reemplazado por SQL con cache (fix D8).
- [ ] Los datos agregados (nunca personales) quedan expuestos en JSON público (`/territorios/:slug.json`) — semilla de la API abierta.

### 3.3 Propuestas de fondo con hitos

**Criterios de aceptación**
- [ ] Una propuesta `fund_transfer` puede definir 2–5 hitos con montos parciales; cada desembolso requiere confirmación (mini-voto o confirmación del proponente + un moderador, según parámetro).
- [ ] El fondo solo desembolsa el hito aprobado; cada desembolso es una `CreditTransaction` propia con ledger balanceado.
- [ ] La página de la propuesta muestra el avance de hitos públicamente.

---

## 6. Fase 4 — Distribución móvil (en paralelo, es más operación que código)

### 4.1 Play Store

**Criterios de aceptación**
- [ ] APK firmado con keystore respaldado (el keystore en el backup cifrado, no en el repo).
- [ ] Ficha de Play Store completa (screenshots, descripción, privacidad → `/privacidad`) y app publicada al menos en track cerrado/beta.
- [ ] Deep links verificados: abrir `confianza.world/<ruta>` en Android abre la app en esa ruta.

### 4.2 Push nativo (FCM)

**Criterios de aceptación**
- [ ] La app Android registra token FCM contra `PushSubscription` (o tabla hermana) y recibe notificaciones con la app cerrada.
- [ ] Tap en la notificación abre la pantalla correcta (interacción, mensaje, match).
- [ ] Un dispositivo deslogueado deja de recibir push (test de limpieza de tokens).

---

## 7. Qué NO hacer todavía

- **IA contextual / matching semántico**: primero el matching determinístico
  por categoría+radio (2.2). Con datos de uso reales se decide si hace falta.
- **API pública completa**: empezar solo con los JSON agregados de territorio
  (3.2); la API formal cuando haya consumidores reales.
- **iOS / Flutter**: Android primero; la tesis móvil se valida ahí.
- **Federación / descentralización técnica**: la descentralización de Confianza
  es de gobernanza (Fase 3), no de protocolo. No tocar hasta tener masa.

## 8. Métricas norte por fase

| Fase | Métrica | Hoy |
|------|---------|-----|
| 1 | % de disputas resueltas en < 7 días | ∅ (imposible resolver) |
| 2 | % de pedidos con ≥ 1 interacción en 72 h | ∅ (no hay pedidos) |
| 2 | Interacciones iniciadas / semana | baseline a medir |
| 3 | Territorios con ≥ 1 regla local activa | 0 |
| 4 | % de sesiones desde la app Android | ~0 |

## 9. Orden sugerido de sesiones

1. Disputas (1.1) — 2–3 sesiones
2. Integridad (1.4) — 1 sesión
3. Búsqueda pg_search (2.1) — 1 sesión
4. Pedidos + matching (2.2) — 2–3 sesiones
5. Identidad (1.2) + rol moderador (1.3) — 2 sesiones
6. Feed rankeado (2.4) + alertas (2.3) — 2 sesiones
7. PostGIS (2.5) — 1–2 sesiones
8. Parámetros territoriales (3.1) — 2–3 sesiones
9. Play Store + FCM (4.x) — según trámites
10. Panel territorial (3.2) + hitos (3.3) — 2–3 sesiones

Cada bloque termina con: suite verde, deploy con Kamal, novedad en `/novedades`
si es visible para usuarios (regla de CLAUDE.md).
