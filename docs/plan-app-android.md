# Plan: app de Android para Confianza

> Actualizado el 2026-07-11. Documento privado de operación.
> Versión anterior (2026-07-10) proponía TWA con Bubblewrap — quedó obsoleta:
> **la app nativa ya existe** en `../confianza-android` (Hotwire Native, junio 2026).

## Estado real (corrección al plan de ayer)

La app de Android **ya está construida** con Hotwire Native 1.2.5 en
`~/workspace/proyectos/negocio/proyecto-confianza/confianza-android`:

- Cascarón Kotlin que navega `https://confianza.world` con stack nativo.
- **Keystore de release creado** (`~/keystores/confianza-release.keystore`,
  credenciales en `keystore.properties` gitignored) y firma configurada:
  `./gradlew bundleRelease` genera el AAB listo para Play Store.
- Path configuration remota (`/configurations/android_v1.json`) con fallback
  local — las reglas de navegación se actualizan desde el servidor.
- El servidor detecta la app (`hotwire_native_app?`) y oculta el chrome web.
- Geolocalización con prompt nativo; insets de la barra de navegación resueltos.

Guía de publicación detallada: `../confianza-android/PLAY_STORE.md`.

## ¿Hay que "actualizar" el APK porque la web avanzó?

**No.** La app carga la web en vivo: Vitrina 2.0, alertas guardadas,
disputas, mensajes directos, etc. llegan solos sin re-publicar. Solo hace
falta una versión nueva del APK/AAB si cambia algo **nativo** (permisos,
íconos, navegación nativa, versión de Hotwire Native).

Antes de cada publicación conviene recompilar y probar en teléfono real
para confirmar que nada nativo se rompió — pero no por los cambios web.

## Deudas del manifest PWA — ✅ resueltas (2026-07-11)

- `theme_color`/`background_color`: `"red"` → `#0f5238`. ✅
- `description` real. ✅
- Pendiente opcional: `screenshots` y `shortcuts` en el manifest (los usa el
  instalador de Chrome; Play Store usa su propia ficha).

## Lo que falta para estar en Play Store

1. **Cuenta de Google Play Console** (Igor, US$25 una vez):
   [play.google.com/console/signup](https://play.google.com/console/signup).
   La verificación de identidad puede tardar días → crearla cuanto antes.
2. **Compilar release**: `cd ../confianza-android &&
   JAVA_HOME=~/android-toolchain/jdk21 ./gradlew bundleRelease`
   → `app/build/outputs/bundle/release/app-release.aab`.
3. **Probar en teléfono real** (USB, `./gradlew installRelease`): login,
   feed, publicar con foto, geoloc, chat, push, gesto de volver.
4. **Ficha de la tienda**: nombre visible (propuesta: "Confianza — red de
   vecinos"), descripción corta/larga, ≥2 capturas del teléfono, ícono
   512×512, feature graphic 1024×500. Política de privacidad: ya existe
   `/privacidad`. ✅
5. **Subir el AAB** a prueba interna → producción (revisión: 1–7 días la
   primera vez).
6. **Novedad** en `/novedades` cuando esté publicada: "Confianza ahora se
   instala como app en Android".

## Recordatorios técnicos

- **Backup del keystore** fuera de la máquina (perderlo = no poder actualizar
  la app nunca más).
- Actualizaciones futuras: subir `versionCode`/`versionName` en
  `app/build.gradle.kts`, `bundleRelease`, subir a Play Console.
- Hotwire Native para iOS (misma path configuration, `ios_v1.json`) y bridge
  components quedan como paso siguiente; Flutter sigue siendo Fase 3.
