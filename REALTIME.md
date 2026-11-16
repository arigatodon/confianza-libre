# Realtime — dónde aplicar Solid Cable + Turbo Streams

Documento de planificación. Stack: **Solid Cable** (Action Cable adapter sin
Redis, soporte en Rails 8 por default) + **Turbo Streams** (broadcasts vía
HTML diffs). Hay que configurar el `adapter: solid_cable` en
`config/cable.yml` (hoy está en `async`) y opcionalmente el binstub de Solid
Queue para que los broadcasts no bloqueen.

Estado actual: **nada es realtime**. El badge de notificaciones, el status de
una interaction y los comentarios sólo se actualizan al recargar/navegar.
Las decisiones de UX vigentes asumen ese modelo. Cuando habilitemos realtime,
muchos pedazos se sienten *vivos* sin tocar lógica de negocio — sólo
agregamos canales y broadcasts.

---

## Patrón base

1. **Modelo:** `broadcasts_to ->(record) { ... }` en el modelo, o un
   `after_update_commit` explícito con `broadcast_replace_to`.
2. **Vista:** `<%= turbo_stream_from current_user %>` (suscripción por
   usuario) o `<%= turbo_stream_from interaction %>` (por recurso).
3. **DOM target:** un `<turbo-frame id="…">` o `<div id="…">` que el
   broadcast reemplace / actualice / agregue.

Patrón canónico en Rails 8:

```ruby
# app/models/notification.rb
broadcasts_to ->(n) { [n.recipient, :notifications] },
              inserts_by: :prepend, target: "notifications-list"
```

```erb
<%# layout o partial %>
<%= turbo_stream_from current_user, :notifications %>
<div id="notifications-list">
  <%= render @notifications %>
</div>
```

Reemplazar el badge del bell:

```ruby
after_create_commit :update_bell_badge

def update_bell_badge
  broadcast_replace_to [recipient, :bell_badge],
    target: "bell-badge",
    partial: "shared/bell_badge",
    locals: { count: recipient.notifications.unread.count }
end
```

---

## Lista priorizada de aplicaciones

### Prioridad 1 — completar el ciclo de feedback inmediato

- **[[notifications]] Badge del bell + listado en `/notifications`**
  Hoy el badge sólo se actualiza al recargar. Suscribiendo el layout a
  `turbo_stream_from current_user, :notifications`:
  - Cada `Notification.create!` prepende un item al listado y bumpea el badge.
  - Toast (Material snackbar) opcional para avisar "tenés algo nuevo".

- **[[interactions]] Status de una interaction en vivo**
  En `/interactions/:id` suscribir a `turbo_stream_from @interaction`. Cuando
  la contraparte:
  - Acepta / contrapropone → el panel de "Te toca responder" muta sin F5.
  - Confirma el cierre → el panel de "X confirmó / Y aún no" se actualiza.
  - Llega al `completed` → aparece el desglose de la transferencia + el form
    de review.
  Esto es lo que más mata la fricción percibida: hoy hay que estar refrescando.

- **[[comments]] Hilo de comentarios del post**
  Ya existe `Comment` con Turbo Streams parcialmente cableado en el form.
  Suscribir `posts/show` a `turbo_stream_from @post, :comments` para que
  cualquier visitante vea los comments aparecer en vivo.

### Prioridad 2 — features nuevas que nacen realtime

- **[[chat]] Mensajería 1‑a‑1 por Interaction**
  Modelo `Message` (belongs_to interaction, body, user). Stream por
  `interaction`. Es la feature donde el realtime es **requisito**, no
  mejora. Pensado en `pendiente.md` → "Mensajería contextual".
  - Canal: `turbo_stream_from @interaction, :chat`.
  - Cada `Message.create!` broadcast_append al `#messages` del chat.
  - Indicador "X está escribiendo…" (opcional, requiere Action Cable raw,
    no Turbo).

- **[[disputes]] Disputas y moderación**
  Cuando una disputa se abre o un moderador interviene, ambas partes deben
  enterarse en el momento. Suscribir `/interactions/:id` cubre esto si
  el panel de status se renderiza con el branch `disputed`.

- **[[proposals]] Voto en propuestas territoriales (Fase 2)**
  `/territorios/:slug` con propuestas abiertas → barra de votos que se llena
  en vivo. `turbo_stream_from @territory, :proposals`.

### Prioridad 3 — pulido / feed

- **[[reviews]] Review nueva refresca trust ring del perfil**
  Cuando se crea una Review, broadcast al perfil del `reviewed_user` para
  actualizar el ring de confianza + el avg por categoría. Útil si el dueño
  del perfil tiene la pestaña abierta cuando lo evalúan.

- **[[wallet]] Balance + nivel en `/billetera` (cuando exista)**
  Tras un `CreditTransfer.completed`, broadcast a las cuentas de sender,
  receiver y territorio (`turbo_stream_from account`). El balance, el nivel
  y la barra de progreso al siguiente nivel se actualizan en vivo.

- **[[feed]] Posts nuevos en el feed cercano / explore**
  Suscribir `home/index` y `/explore` a `turbo_stream_from :nearby, current_user.territory`
  (o por bbox). Apenas un vecino publica, aparece el card sin F5. Cuidado
  con el ruido — sólo broadcast si está dentro del radio del viewer (filtro
  server-side antes del broadcast).

- **[[trust]] Trust score recomputado**
  Cuando `RecalculateUserTrustJob` termina, broadcast al perfil del usuario
  para refrescar el número. Bajo impacto pero cierra el loop con `[[reviews]]`.

### Prioridad 4 — gobernanza y ops

- **[[ledger]] Endpoint público `/ledger/audit`**
  Streaming de transacciones nuevas (Fase 2). No es prioritario pero es
  bonito mostrar el ledger latiendo.

- **[[admin]] Panel de moderación**
  Cuando exista. Stream de disputas abiertas, reportes, etc.

---

## Wiring mínimo para arrancar

```yaml
# config/cable.yml
development:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.5.seconds
```

Solid Cable usa una DB separada (`cable`) ya configurada en `database.yml` de
proyectos Rails 8 nuevos. Verificar antes de cambiar.

`ApplicationCable::Connection` con `identified_by :current_user` + lookup
por cookie de sesión:

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      session_record = Session.find_by(id: cookies.signed[:session_id])
      session_record&.user || reject_unauthorized_connection
    end
  end
end
```

Esto sólo es necesario para `turbo_stream_from current_user` (streams
ligados a un usuario autenticado). Los streams ligados a recursos públicos
(`@post`, `@interaction`) no necesitan auth en el canal — Action Cable
firma el stream name; cualquier intento de spoof del DOM falla.

---

## Anti‑patrones a evitar

- **Broadcast desde el controller.** Hacer broadcast en callbacks del
  modelo, no en `after_action` del controller — eso pierde los cambios que
  vengan por consola, jobs o flows alternos. Misma regla que con las
  notificaciones (ver `Interaction#notify_status_change`).
- **Streams demasiado granulares.** No suscribir `turbo_stream_from @user`
  *y* `turbo_stream_from current_user, :notifications` *y*
  `turbo_stream_from current_user, :bell` en el mismo layout — cada
  suscripción es una conexión WebSocket. Agrupar por scope.
- **N+1 de broadcasts.** Si un job actualiza muchos modelos, broadcast una
  vez al final con una vista agregada (o un Turbo Stream `update` único)
  en vez de uno por record.
- **Realtime para datos que no cambian solos.** El form de edición de un
  post no necesita stream — sólo lo ve el dueño y se actualiza sólo en
  submit. No streamear por hábito.

---

## Estado actual del repo

- `config/cable.yml` → adapter `async`. Cambiar a `solid_cable` cuando
  arranquemos el primer caso (probablemente notifications + chat).
- Hay `comments/_form.html.erb` con `data-turbo-stream` parcialmente; los
  Turbo Streams como **respuesta al submit** funcionan. Lo que falta es el
  **broadcast a otros viewers** (cross-tab / cross-user).
- Action Cable Connection sin `current_user` identificado todavía.

---

## Orden sugerido cuando arranquemos

1. Habilitar Solid Cable + `ApplicationCable::Connection`.
2. Convertir el badge de notificaciones a stream (smoke test del stack).
3. Status de interaction en `/interactions/:id` (alto impacto, scope chico).
4. Comments del post (replicar el patrón).
5. Modelo `Message` + chat por interaction (feature nueva).
6. Wallet y trust score (después de que existan las vistas correspondientes).
