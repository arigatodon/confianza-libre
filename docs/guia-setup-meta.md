# Guía: activar Instagram + Facebook (setup de Meta)

> **ESTADO 2026-07-10 (noche)**: ✅ **Instagram y Facebook ACTIVOS**, ambos
> verificados con publicación real.
>
> - **Instagram**: cuenta @confianza.world (IG User ID en
>   `.kamal/secrets-common`), permiso `instagram_content_publish`.
> - **Facebook**: página de Confianza creada y vinculada; publica vía
>   `POST /{page-id}/feed`.
> - **Token**: ambos adaptadores usan **EL MISMO Page Access Token**,
>   obtenido de `GET /me/accounts` con un token de usuario de larga
>   duración. Canjeado así, **no caduca** — no hay que renovarlo cada 60
>   días. Está repetido en `INSTAGRAM_ACCESS_TOKEN` y
>   `FACEBOOK_PAGE_ACCESS_TOKEN` (dos nombres, un solo valor).
>
> Si algún día hay que rehacerlo (cambio de contraseña de Facebook lo
> invalida): repetir paso 5 → canje a larga duración → `/me/accounts` → ese
> único Page token va en las dos variables. **No hace falta nada más.**
>
> ⚠️ Pendiente menor: al token actual le falta `instagram_manage_comments`,
> así que el comentario automático "link en la bio" no sale (la publicación
> sí). Se arregla regenerando el token con los **seis** permisos del paso 5.

> Documento privado de operación. Objetivo: que la difusión automática a
> Instagram y Facebook (ya programada en `app/services/difusion/`) quede viva.
>
> **Buena noticia**: la app de Meta ya existe de tu intento anterior — su
> App ID y App Secret están guardados en `.kamal/secrets-common` como
> `FACEBOOK_ID` / `FACEBOOK_SECRET`. No hay que crearla de nuevo.

## División del trabajo

- **Tu parte (pasos 1–5, ~30–45 min)**: cuentas, página, vinculación y
  generar un token corto. Todo se hace clickeando en Meta, no hay código.
- **Mi parte (paso 6)**: me pegas el token corto en el chat y yo hago el
  canje por tokens permanentes, saco los IDs, completo los secrets y
  despliego. El token corto vence en ~1–2 horas, así que pégamelo apenas
  lo generes.

---

## Paso 1 — Cuenta de Instagram profesional

1. Si Confianza aún no tiene cuenta de Instagram, créala (ej: `@confianza.world`).
2. En la app de Instagram: **Configuración → Tipo de cuenta y herramientas →
   Cambiar a cuenta profesional → Empresa** (no "Creador").
3. Es gratis y reversible. Sin esto la API no puede publicar.

## Paso 2 — Página de Facebook

1. Desde tu perfil personal de Facebook: **Menú → Páginas → Crear página**.
2. Nombre: **Confianza** (o "Confianza — confianza.world"). Categoría:
   algo tipo "Sitio web de comunidad".
3. La API de Instagram exige que exista esta página aunque casi no la uses.

## Paso 3 — Vincular Instagram a la página

Lo más fácil es desde la app de Instagram:

1. **Editar perfil → Vinculación de página** (o "Conectar página de Facebook").
2. Elige la página Confianza que creaste en el paso 2.

Alternativa: en [business.facebook.com](https://business.facebook.com) →
Configuración → Cuentas → Instagram → Conectar.

## Paso 4 — Revisar la app en developers.facebook.com

1. Entra a [developers.facebook.com/apps](https://developers.facebook.com/apps)
   con tu cuenta personal — debería aparecer la app que creaste antes
   (el App ID termina en `...6944`; compáralo con `FACEBOOK_ID` en
   `.kamal/secrets-common`).
2. Verifica que esté en **modo Desarrollo**: está perfecto así. En modo
   desarrollo la app puede publicar en cuentas donde tú eres admin — que es
   exactamente nuestro caso. **No hace falta App Review.**
3. Si en el panel de la app aparece la opción de agregar productos, agrega
   **"Instagram" / "Instagram Graph API"** si no está ya. Si Meta te pide
   elegir un "caso de uso", elige el que mencione administrar páginas y
   publicar contenido. (Meta cambia estos menús seguido; si algo no calza
   con esta guía, sácale pantallazo y lo vemos juntos.)

## Paso 5 — Generar el token corto (Graph API Explorer)

1. Abre [developers.facebook.com/tools/explorer](https://developers.facebook.com/tools/explorer).
2. Arriba a la derecha:
   - **Aplicación de Meta**: elige tu app de Confianza.
   - **Usuario o página**: "Token de acceso de usuario" (User Token).
3. En **Permisos**, agrega estos seis:
   - `pages_show_list`
   - `pages_read_engagement`
   - `pages_manage_posts`
   - `instagram_basic`
   - `instagram_content_publish`
   - `instagram_manage_comments` ← necesario para el comentario automático
     "link en la bio" (el token de 2026-07-10 se generó SIN este permiso, por
     eso el comentario falla con error #10 y solo sale el caption)
4. Clic en **Generate Access Token** → se abre un popup de login de Facebook:
   acepta y cuando pregunte, **selecciona la página Confianza y la cuenta de
   Instagram** vinculada.
5. Copia el token que aparece (empieza con `EAA...`) y **pégamelo en el chat
   de inmediato** junto con la palabra "token".

## Paso 6 — Mi parte (automática)

Con el token corto yo hago:

1. Canje por **token de usuario de larga duración** (usa `FACEBOOK_ID` +
   `FACEBOOK_SECRET`, endpoint `oauth/access_token`).
2. Con ese token pido `GET /me/accounts` → obtengo el **Page ID** y el
   **Page Access Token** (este, canjeado así, **no caduca** — nos evita
   renovar tokens cada 60 días).
3. `GET /{page-id}?fields=instagram_business_account` → **IG User ID**.
4. Verifico con `GET /{ig-user-id}?fields=username` que apunte a la cuenta
   correcta.
5. Completo en `.kamal/secrets-common`:
   `INSTAGRAM_USER_ID`, `INSTAGRAM_ACCESS_TOKEN`, `FACEBOOK_PAGE_ID`,
   `FACEBOOK_PAGE_ACCESS_TOKEN` (las claves ya están creadas, vacías).
6. `bin/kamal env push` + restart. Los adaptadores se activan solos
   (`Difusion::Instagram.configurada?` pasa a true).
7. Prueba real: publicar un post con "Difundir en las redes de Confianza"
   y revisar `social_broadcasts` + la cuenta de IG y la página de FB.

## Problemas típicos

- **"No apareces como admin de la página"** en el Explorer → la página se
  creó con otra cuenta, o falta aceptar el popup del paso 5.4 marcando la
  página.
- **Instagram no aparece en el popup** → falló la vinculación del paso 3;
  rehacerla desde la app de Instagram.
- **Error de versión de API** al publicar → los adaptadores usan Graph API
  v21.0; si Meta la jubiló, se sube la constante `VERSION` en
  `app/services/difusion/instagram.rb` y `facebook.rb` (un cambio de una
  línea, avísame).
- **La app pide "verificación del negocio"** → solo aplica para modo Live /
  App Review. En modo desarrollo publicando en cuentas propias no hace falta.

## Cómo quedó activado Facebook (bitácora 2026-07-10)

1. Igor creó la **página de Facebook de Confianza** y la vinculó a la cuenta
   de Instagram (pasos 2–3 de esta guía).
2. Se regeneró el token corto en el Graph API Explorer con los cinco
   permisos del paso 5 (esta vez `/me/accounts` ya traía la página).
3. Canje a token de usuario de larga duración → `GET /me/accounts` devolvió
   el **Page ID** y el **Page Access Token que no caduca**.
4. Ese único Page token se escribió en `.kamal/secrets-common` **dos veces**:
   como `FACEBOOK_PAGE_ACCESS_TOKEN` y también reemplazando el
   `INSTAGRAM_ACCESS_TOKEN` de 60 días — así ninguna de las dos redes
   necesita renovación periódica.
5. Deploy + prueba real: el post salió bien en Facebook (texto + link con
   vista previa de la tarjeta) y en Instagram (tarjeta 1080×1080).

Ajuste posterior al primer post de Instagram: el caption ya no lleva `@usuario`
(en IG el arroba etiqueta cuentas ajenas) ni URL cruda; la invitación va como
primer comentario apuntando al **link en la bio** — mantener el link a
confianza.world en la bio de @confianza.world.

## Nota de mantenimiento

El Page Access Token obtenido de un token de usuario de larga duración no
expira, pero **se invalida si cambias la contraseña de Facebook o cierras
sesión en todos los dispositivos**. Si algún día la difusión deja de llegar a
IG/FB, lo primero es regenerar el token (repetir paso 5 + pedirme el canje) —
recordando que **el mismo Page token va en las dos variables**.
