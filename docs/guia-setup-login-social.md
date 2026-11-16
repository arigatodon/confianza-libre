# Guía: activar "Entrar con Google / Microsoft"

> Documento privado de operación. Lo público se anuncia en `/novedades`
> sin detalles de credenciales.

El código ya está (`app/services/oauth/`, `OauthSessionsController`). Cada
proveedor aparece en `/session/new` y `/signup` **solo si tiene sus dos
variables de entorno**. Sin variables, nada cambia para los usuarios.

URLs de callback que hay que registrar en cada proveedor:

| Proveedor | URL de redirección |
|-----------|--------------------|
| Google    | `https://confianza.world/auth/google/callback` |
| Microsoft | `https://confianza.world/auth/microsoft/callback` |

(Para desarrollo local, agregar además `http://localhost:3000/auth/<proveedor>/callback`.)

## Google (Gmail) — ~10 minutos

1. [console.cloud.google.com](https://console.cloud.google.com) → crear proyecto
   "Confianza" (o reusar el que tiene la API key de Gemini).
2. **APIs y servicios → Pantalla de consentimiento OAuth**: tipo *Externo*,
   nombre "Confianza", email de soporte, dominio autorizado `confianza.world`,
   links a `https://confianza.world/privacidad`. Scopes: `openid`, `email`,
   `profile` (no requieren verificación de Google).
3. **Publicar** la app (estado "En producción"). Con solo esos scopes no hay
   revisión; en "Prueba" solo podrían entrar los emails de prueba listados.
4. **Credenciales → Crear credenciales → ID de cliente de OAuth**: tipo
   *Aplicación web*, orígenes `https://confianza.world`, URI de redirección
   la de la tabla. Copiar **ID de cliente** y **Secreto**.
5. Variables:
   ```
   GOOGLE_OAUTH_CLIENT_ID=1234-abc.apps.googleusercontent.com
   GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-...
   ```

## Microsoft (Hotmail, Outlook, Live, cuentas de trabajo) — ~10 minutos

1. [portal.azure.com](https://portal.azure.com) → **Microsoft Entra ID →
   Registros de aplicaciones → Nuevo registro**.
2. Nombre "Confianza". Tipos de cuenta: **"Cuentas en cualquier directorio
   organizativo y cuentas personales de Microsoft"** (imprescindible para
   Hotmail/Outlook). Plataforma *Web*, URI de redirección la de la tabla.
3. En **Información general** copiar el *Id. de aplicación (cliente)*.
4. **Certificados y secretos → Nuevo secreto de cliente** (vence en 6, 12 o
   24 meses — anotar la fecha y renovar antes). Copiar el **valor** (no el id).
5. **Permisos de API**: `openid`, `email`, `profile` de Microsoft Graph
   (delegados; vienen por defecto). No hace falta consentimiento de admin.
6. Variables:
   ```
   MICROSOFT_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
   MICROSOFT_OAUTH_CLIENT_SECRET=abc...
   ```

## Activar en producción

Agregar las variables a `.kamal/secrets-common` (ya están declaradas en
`config/deploy.yml` → `env.secret`), luego:

```bash
bin/kamal env push && bin/kamal app restart
```

Probar: `/session/new` muestra los botones; entrar con una cuenta nueva crea
el usuario con email verificado y lo manda a `/bienvenida`; entrar con el
email de un usuario existente le vincula la cuenta sin duplicarla.

## Cómo funciona (para depurar)

- `GET /auth/:provider` guarda un `state` aleatorio en la sesión y redirige al
  proveedor. `GET /auth/:provider/callback` valida el `state`, canjea el
  `code` por tokens (`Oauth::Proveedor#perfil`) y llama a `Oauth::Ingreso`.
- `Oauth::Ingreso`: identidad existente → entra; email conocido → vincula;
  si no → crea usuario (username derivado del nombre, password aleatorio,
  `email_verified_at` puesto, avatar importado en segundo plano).
- Un usuario creado así puede fijar contraseña con "Olvidé mi contraseña".
- **App Android**: los botones no se muestran dentro de Hotwire Native
  (Google bloquea su login en WebViews). Pendiente: abrir el flujo en Chrome
  Custom Tab desde la app y volver con un deep link.
