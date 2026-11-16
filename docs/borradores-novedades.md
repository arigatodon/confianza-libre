# Borradores para /novedades

Listos para copiar y pegar en "Nueva novedad" (`/novedades` → Nueva novedad,
requiere tu usuario con admin = true). El cuerpo usa párrafos separados por
línea en blanco — el formato se respeta tal cual.

---

## 1 · kind: Versión

**Título:** Nace Confianza: una red donde el valor lo creamos entre vecinos

**Cuerpo:**

Hoy abrimos la bitácora de Confianza. Acá vamos a contar, en simple, cada cambio de la red: qué construimos, por qué, y qué decide la comunidad.

¿Por qué existe esto? Porque creemos que antes del dinero está la deuda entre personas que se conocen, y que esa deuda no necesita un banco en el medio. En Confianza todos parten de cero: lo que tenés es lo que la red confía en vos, y eso se gana participando.

¿Qué ya funciona hoy? Perfiles públicos con reputación, publicaciones georreferenciadas (ventas, servicios, eventos, pedidos de ayuda), créditos mutuos con contabilidad de partida doble, evaluaciones entre vecinos, fondo territorial que se alimenta con cada intercambio, y propuestas comunitarias para decidir en qué se usa.

Todo lo que rige la economía es público y auditable en confianza.world/economia. Y desde hoy, cada avance se publica acá.

Si querés entender la idea de fondo, leé el manifiesto: confianza.world/manifiesto

---

## 2 · kind: Cambio

**Título:** Invitá a tus vecinos: tu link personal de invitación

**Cuerpo:**

La red crece de a una persona de confianza a la vez. Por eso ahora cada miembro tiene su link personal de invitación: confianza.world/invita/tu-usuario.

Quien se registre con tu link queda apadrinado por vos y arranca con un colchón extra de crédito — porque entrar de la mano de alguien que ya participa es la mejor garantía que existe.

También sumamos botones para compartir publicaciones y perfiles por WhatsApp o por donde quieras. Lo encontrás en tu perfil, en la caja "Invitá a tus vecinos".

El padrinazgo no es un programa de puntos: es la forma en que la confianza entra a la red. Tu ahijado lleva tu nombre al lado del suyo.

---

## 3 · kind: Cambio

**Título:** La comunidad ya puede cambiar las reglas del juego

**Cuerpo:**

Hasta ahora, las propuestas comunitarias servían para decidir en qué usar el fondo del territorio. Desde hoy sirven para mucho más: para cambiar las reglas de la red.

Hay tres tipos de propuesta. Créditos del fondo: destinar créditos del fondo territorial a un vecino o iniciativa (como siempre). Nueva categoría: proponer una categoría nueva para publicar — si la comunidad la aprueba, se crea. Cambio de regla: modificar un parámetro de la economía — la quema por transacción, el aporte al fondo, el quórum, los días de votación y más.

Cada regla tiene un rango seguro (por ejemplo, la quema solo puede estar entre 0% y 10%) para que ninguna votación pueda romper la red. Y cuando una propuesta aprobada se ejecuta, el cambio se aplica de verdad, al instante, para todos.

Para proponer cambios de reglas hace falta nivel 2: la confianza para cambiar el juego se gana participando. Votar puede hacerlo cualquier miembro.

Esto es lo que llamamos descentralizar el poder: que las decisiones que en cualquier plataforma toma una empresa, acá las tome la red.

---

## 4 · kind: En consulta (ejemplo de consulta a la comunidad)

**Título:** ¿Qué construimos después? Mensajes mejorados o mapa de territorios

**Cuerpo:**

Queremos que el rumbo del desarrollo también se decida acá adentro. Esta es la primera consulta abierta.

Tenemos dos caminos posibles para el próximo ciclo. Mensajes mejorados: notificaciones más claras, respuestas más rápidas dentro de cada interacción. Mapa de territorios: ver la actividad de tu comuna en el mapa, con el fondo territorial y las propuestas activas.

Si esta novedad junta apoyos, avanzamos por el camino que la comunidad marque. Apoyá esta publicación si te interesa que sigamos consultando el rumbo de esta forma, y contanos en feedback cuál de las dos opciones te sirve más.

---

### Recordatorio para publicar

1. En producción, marcá tu usuario como admin (una sola vez):
   `bin/kamal console` → `User.find_by(username: "igor").update!(admin: true)`
2. Entrá a confianza.world/novedades → "Nueva novedad".
3. Elegí el tipo, pegá título y cuerpo, y "Publicar" (o "Guardar borrador").
