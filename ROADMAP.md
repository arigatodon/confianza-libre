# Roadmap de Confianza

Actualizado: 2026-06-09. Este documento ordena lo que falta por construir.
El principio: **primero que no se pierda nada, después que la primera comuna
funcione de verdad, después escalar.** El orden de lo no-crítico se decide
con consultas en [/novedades](https://confianza.world/novedades) — el roadmap
también es de la comunidad.

## Hecho (a junio 2026)

- MVP completo: perfiles públicos, publicaciones georreferenciadas, categorías,
  feed cercano, mapa, evaluaciones, créditos con partida doble, billetera,
  niveles, decay, moderación, logros, onboarding, emails transaccionales.
- Gobernanza real: propuestas de fondo, categorías nuevas y cambio de reglas
  con quórum que escala con la red y umbrales territoriales gobernables.
- Apertura: /manifiesto, /novedades (blog + RSS + consultas con apoyos),
  /economia con reglas en vivo.
- Crecimiento: links de invitación /invita/:code, botones de compartir,
  SEO completo (sitemap en Search Console), campañas por email
  (novedades:digest / novedades:verifica).
- App Android (Hotwire Native), APK debug funcionando.
- Deploy con Kamal en un VPS + dominio confianza.world con HTTPS.

## Ahora — confiabilidad (días)

Lo que protege lo que ya existe. No se vota: es responsabilidad.

1. **Backups automáticos de PostgreSQL** ⚠️ URGENTE — hoy la base (usuarios,
   ledger, todo) vive en un volumen Docker del mismo VPS, sin copia. Un
   `pg_dump` diario cifrado a almacenamiento externo (S3/B2/otro VPS) +
   prueba de restore. Sin esto, un disco roto borra la red.
2. **Monitoreo**: errores (Sentry o self-hosted) + uptime + alerta si el
   sitio cae. Hoy nos enteraríamos por un usuario.
3. **Entregabilidad de email**: verificar DKIM/SPF/DMARC de confianza.world
   (los 3 usuarios sin verificar pueden ser síntoma de correos en spam).
4. **Analytics con privacidad** (Plausible/Umami self-hosted): saber cuánta
   gente llega desde Google/redes y dónde abandona, sin vender datos de nadie.

## Próximo — que la primera comuna funcione (semanas)

5. **App Android en el teléfono y en Play Store**: probar el APK, firmarlo,
   publicarlo. La red es móvil o no es.
6. **Verificación por teléfono**: los niveles 3+ la exigen y hoy no existe el
   camino (gate sin puerta). Alternativa más alineada con el proyecto:
   **aval entre vecinos** (N usuarios de nivel alto te verifican en persona)
   en lugar de SMS pago. Decidir con una consulta.
7. **Mensajería directa**: hoy solo hay chat dentro de una interacción.
   Vecinos que se conocen necesitan hablar antes de transaccionar.
8. **Notificaciones push** (web push + Android): el service worker ya existe,
   falta conectarlo. Sin push, la app se olvida.
9. **Mapa de territorios**: la actividad de la comuna, su fondo y sus
   propuestas visibles en el mapa de /explore.

## Después — escala y descentralización real (meses)

10. **Reglas locales por territorio**: la promesa grande del manifiesto —
    parámetros económicos con override por comuna, que evolucionan a globales
    con los mínimos de participación. Requiere que toda la economía lea
    parámetros territoriales; hacerlo cuando haya comunas con masa real.
11. **Antifraude inteligente**: detección de multicuentas por grafo de
    interacciones (los límites L1 ya existen como primera barrera).
12. **API pública / exportación**: "todo abierto" también para los datos
    agregados de la red (economía, gobernanza), nunca los personales.
13. **IA contextual** (Fase 3 de la visión): sugerencias de publicaciones y
    matching entre necesidades y ofertas cercanas.

## Cómo se decide el orden

- Lo de **Ahora** no se vota: backups y monitoreo son el piso.
- Lo de **Próximo** y **Después** se prioriza con consultas en /novedades
  (apoyos) y, cuando la red tenga masa, con propuestas formales votadas.
