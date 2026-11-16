Geocoder.configure(
  lookup: :nominatim,
  language: :es,
  units: :km,
  timeout: 5,
  # Nominatim exige identificar la app con un contacto válido. Se toma del
  # entorno (GEOCODER_CONTACT, o ALERT_EMAIL) para no dejar correos en el código.
  http_headers: {
    "User-Agent" => "Confianza/0.1 (+https://confianza.world; contact: #{ENV["GEOCODER_CONTACT"].presence || ENV["ALERT_EMAIL"].presence || "no-reply@confianza.world"})"
  }
)
