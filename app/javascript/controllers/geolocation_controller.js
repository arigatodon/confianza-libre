import { Controller } from "@hotwired/stimulus"

// Captura la posición actual del navegador y la escribe en los targets
// latitudeField / longitudeField. También la persiste vía POST a /geolocation
// para que el feed cercano del servidor pueda usarla.
export default class extends Controller {
  static targets = ["latitudeField", "longitudeField", "status", "button"]
  static values = {
    persistUrl: { type: String, default: "/geolocation" },
    csrfSelector: { type: String, default: "meta[name='csrf-token']" }
  }

  connect() {
    if (!("geolocation" in navigator)) {
      this.#setStatus("Tu navegador no soporta geolocalización.")
      if (this.hasButtonTarget) this.buttonTarget.disabled = true
    }
  }

  request(event) {
    event?.preventDefault()
    if (!("geolocation" in navigator)) return

    this.#setStatus("Pidiendo permiso de ubicación…")
    if (this.hasButtonTarget) this.buttonTarget.disabled = true

    navigator.geolocation.getCurrentPosition(
      (pos) => this.#onSuccess(pos),
      (err) => this.#onError(err),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    )
  }

  #onSuccess(position) {
    const { latitude, longitude } = position.coords
    if (this.hasLatitudeFieldTarget) this.latitudeFieldTarget.value = latitude
    if (this.hasLongitudeFieldTarget) this.longitudeFieldTarget.value = longitude
    this.#setStatus(`Ubicación capturada (${latitude.toFixed(4)}, ${longitude.toFixed(4)}).`)
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
    this.#persist(latitude, longitude)
  }

  #onError(error) {
    const messages = {
      1: "Denegaste el permiso de ubicación.",
      2: "No se pudo obtener tu ubicación.",
      3: "Timeout esperando la ubicación."
    }
    this.#setStatus(messages[error.code] || "Error obteniendo ubicación.")
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
  }

  #setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  #persist(latitude, longitude) {
    const token = document.querySelector(this.csrfSelectorValue)?.content
    fetch(this.persistUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ latitude, longitude })
    }).catch(() => { /* silencio: la cookie es best-effort */ })
  }
}
