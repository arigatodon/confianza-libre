# Difusión en redes sociales

> Documento privado de operación. Lo público de esta feature se anuncia en
> `/novedades` sin detalles de infraestructura.

## Qué hace

Cuando un usuario publica un post y marca **"Difundir en las redes de
Confianza"** (consentimiento explícito, apagado por defecto), un job en
segundo plano:

1. Genera una **tarjeta PNG 1080×1080** con la marca de Confianza: título,
   categoría, descripción corta, `@usuario`, comuna (vía TerritoryResolver) y
   `confianza.world`. Si el post tiene foto, la usa de fondo oscurecida; si
   no, degradado verde institucional.
   - **Privacidad**: nunca aparece la ubicación exacta ni coordenadas — solo
     la comuna/ciudad.
2. La publica en cada red configurada, con texto + link al post.
3. Registra cada envío en `social_broadcasts` (idempotente: una sola
   publicación por red por post, los reintentos no duplican).

Bonus: la tarjeta también es la **og:image** de todo post (`/posts/:slug/tarjeta.png`),
así los links compartidos por WhatsApp/Telegram muestran vista previa con marca.

## Probar la tarjeta localmente

```bash
bin/rails s
# luego abrir http://localhost:3000/posts/<slug>/tarjeta.png
```

O por consola: `File.binwrite("/tmp/t.png", Difusion::Tarjeta.new(Post.last).render)`.

## Redes soportadas

Cada red se activa sola cuando sus variables de entorno existen. Sin
variables, esa red se saltea silenciosamente (dev y test no publican nada).

### 1. Telegram (5 minutos, recomendado primero)

1. Hablarle a **@BotFather** en Telegram → `/newbot` → nombre y username
   (ej: `ConfianzaBot`). Guardar el **token**.
2. Crear un **canal público** (ej: `@confianza_chile`) y agregar el bot como
   **administrador** con permiso de publicar.
3. Variables:
   ```
   TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
   TELEGRAM_CHAT_ID=@confianza_chile
   ```

### 2. Bluesky (5 minutos)

1. Crear la cuenta (ej: `confianza.world` como handle custom, o
   `confianza.bsky.social`).
2. Settings → Privacy and Security → **App Passwords** → crear una. **No usar
   la contraseña real.**
3. Variables:
   ```
   BLUESKY_IDENTIFIER=confianza.bsky.social
   BLUESKY_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
   ```

### 3. Instagram (✅ ACTIVO desde 2026-07-10 — ver docs/guia-setup-meta.md)

`Difusion::Instagram` publica en dos pasos (crear contenedor con la URL
pública de la tarjeta + `media_publish`) y espera a que el contenedor quede
`FINISHED` antes de publicar.

Particularidades del copy en IG:

- El caption va **sin `@usuario`** — en Instagram el arroba etiqueta cuentas
  de IG que no son la persona de confianza.world.
- Tampoco lleva la URL del post (no es clickeable en IG). En su lugar, tras
  publicar se deja un **primer comentario** invitando a entrar al **link en
  la bio** (`COMENTARIO_CTA`). Mantener el link a confianza.world en la bio.

Instagram no acepta posts de texto por API: por eso existe la tarjeta. El
camino completo (lo hace Igor una sola vez en Meta):

1. **Cuenta de Instagram** para Confianza → convertirla a **Professional
   (Business)** desde la app (Settings → Account type).
2. **Página de Facebook** de Confianza (la API la exige) y **vincularla** a la
   cuenta de IG (Settings de la página → Linked accounts).
3. En [developers.facebook.com](https://developers.facebook.com): crear una
   **app** tipo Business. Agregar el producto **Instagram Graph API**.
4. Con el **Graph API Explorer** generar un token con permisos
   `instagram_basic`, `instagram_content_publish`, `pages_read_engagement`.
   Mientras la app esté en modo desarrollo funciona para cuentas propias
   (admin/tester de la app) — no hace falta app review para publicar en
   nuestra propia cuenta.
5. Canjear por **token de larga duración** (60 días) y obtener el
   **IG User ID**.
6. Variables (con esto el adaptador ya publica solo):
   ```
   INSTAGRAM_USER_ID=178414...
   INSTAGRAM_ACCESS_TOKEN=EAAG...
   ```

Limitación de la API: la imagen debe estar en una **URL pública** — usamos
justamente `https://confianza.world/posts/<slug>/tarjeta.png`, así que no hay
que subir nada a ningún lado.

### 4. Facebook Page (✅ ACTIVO desde 2026-07-10 — mismo setup de Meta que Instagram)

`Difusion::Facebook` publica **texto + link** en el feed de la página
(`POST /{page-id}/feed`). Facebook arma la vista previa con la og:image del
post — que es la tarjeta — y el resultado queda clickeable (mejor conversión
que subir la foto suelta).

Se hace junto con el setup de Instagram (misma app de Meta, pasos 1–3 del
punto anterior). Lo extra:

1. Al generar el token en el Graph API Explorer, sumar el permiso
   **`pages_manage_posts`** (además de los de Instagram).
2. Obtener el **Page Access Token**: con el token de usuario, pedir
   `GET /me/accounts` — la respuesta trae el `id` de la página y su
   `access_token`. Canjeado desde un token de usuario de larga duración,
   el Page Access Token **no expira**.
3. Variables:
   ```
   FACEBOOK_PAGE_ID=1029384...
   FACEBOOK_PAGE_ACCESS_TOKEN=EAAG...
   ```

**Importante**: el mismo Page Access Token (que no caduca) sirve para las dos
redes — va repetido en `INSTAGRAM_ACCESS_TOKEN` y `FACEBOOK_PAGE_ACCESS_TOKEN`.

## Fondo generado con IA para posts informativos

Las publicaciones de tipo `noticia`/`blog` (las novedades del proyecto) casi
nunca traen foto, y la tarjeta salía siempre con el degradado verde. Ahora
`DifundirPostJob` genera **una vez** un fondo con IA (`Difusion::ImagenIa`,
modelo Nano Banana 2 Lite / `gemini-3.1-flash-lite-image` de la Gemini API) y
lo adjunta al post como `imagen_difusion` — todos los renders de la tarjeta
(difusión, og:image, descarga de Meta) usan esa misma imagen.

- Solo actúa si el post no tiene foto propia y `GOOGLE_API_KEY` existe.
- El prompt pide escena de comunidad **sin texto ni logos** (el texto lo pone
  la tarjeta encima).
- Si la generación falla, la tarjeta cae sola al degradado — nunca bloquea
  la difusión.

Variable: `GOOGLE_API_KEY` (API key de Google AI Studio) en
`.kamal/secrets-common` + `config/deploy.yml`.

### 5. WhatsApp (sin API de publicación — cubierto por otro lado)

No existe API para publicar en canales ni estados de WhatsApp. Cobertura real:

- **Botón WhatsApp en cada post** (`shared/_share_button`): los usuarios
  reenvían a sus grupos con un toque — en Chile ese boca a boca vale más que
  cualquier cuenta oficial.
- **La og:image es la tarjeta**: todo link de Confianza pegado en WhatsApp
  muestra la vista previa con marca.
- **Canal de WhatsApp de Confianza** (manual): el canal de Telegram recibe
  la tarjeta lista → reenviarla al canal de WhatsApp toma 10 segundos.

### 6. TikTok (manual por ahora)

Su Content Posting API exige registro de app + revisión, y el formato es
video. No se justifica automatizar todavía. Camino manual si se quiere
presencia: descargar la tarjeta (`/posts/<slug>/tarjeta.png`) y subirla como
foto-post desde la app, o hacer videos cortos mostrando la app real. Cuando
haya volumen de posts con foto se puede evaluar un generador de slideshows.

## Orden recomendado para Chile

Lo que más se usa acá: WhatsApp, Instagram, Facebook, TikTok.

1. **WhatsApp ya funciona hoy** (botón + og:image) — no requiere setup.
2. **Un solo setup de Meta habilita Instagram + Facebook** a la vez
   (puntos 3 y 4): es la mayor ganancia por esfuerzo.
3. **Telegram** (5 min) sirve como "consola" de difusión: cada tarjeta llega
   lista para reenviar a donde sea, incluido el canal de WhatsApp.
4. TikTok manual, solo si sobra energía.

## Variables en producción

Agregar las variables a `.kamal/secrets-common` y referenciarlas en
`config/deploy.yml` bajo `env.secret`, luego `bin/kamal env push` +
`bin/kamal app restart` (o un deploy normal).

## Arquitectura (para agregar redes)

```
app/services/difusion/tarjeta.rb    # generador PNG (ruby-vips)
app/services/difusion/imagen_ia.rb  # fondo IA para posts informativos (Gemini)
app/services/difusion/telegram.rb   # adaptador Telegram
app/services/difusion/bluesky.rb    # adaptador Bluesky
app/services/difusion/instagram.rb  # adaptador Instagram (Graph API)
app/services/difusion/facebook.rb   # adaptador Facebook Page (Graph API)
app/jobs/difundir_post_job.rb       # orquesta: tarjeta + texto + cada red
app/models/social_broadcast.rb      # registro idempotente de envíos
```

Un adaptador nuevo = una clase con `NETWORK`, `self.configurada?` y
`#publicar(tarjeta_png:, texto:, url:, tarjeta_url:)` que devuelve el id
externo, sumada a `DifundirPostJob::ADAPTADORES`. La mayoría usa los bytes
(`tarjeta_png:`); Instagram en cambio usa `tarjeta_url:` (URL pública) porque
la Graph API descarga la imagen en vez de recibirla.

## Pendientes / ideas siguientes

- Digest semanal como carrusel ("Esta semana en Confianza…").
- Captions con tono por red (plantillas; más adelante API de Claude).
- Botón "ver cómo quedó" en el post para el autor (links a los envíos).
