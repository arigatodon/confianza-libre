import { Controller } from "@hotwired/stimulus"
import maplibregl from "maplibre-gl"

// Modal con MapLibre para elegir ubicación clickeando sobre el mapa.
// Targets:
//   latitudeField, longitudeField  -> inputs hidden/visibles del form
//   modal, mapContainer            -> contenedores del modal
//   coords                          -> span que muestra lat/lng elegida
//   confirmBtn                      -> botón para confirmar selección
//   summary                         -> span en la card del form que muestra
//                                      "Ubicación elegida" o "Sin elegir"
export default class extends Controller {
  static targets = [
    "latitudeField", "longitudeField",
    "modal", "mapContainer", "coords", "confirmBtn", "summary"
  ]

  connect() {
    this.#renderSummary()
  }

  disconnect() {
    this.#destroyMap()
  }

  open(event) {
    event?.preventDefault()
    this.modalTarget.classList.remove("hidden")
    // Pequeño defer para que el modal pinte y el map calcule el tamaño bien.
    requestAnimationFrame(() => this.#initMap())
  }

  close(event) {
    event?.preventDefault()
    this.modalTarget.classList.add("hidden")
    this.#destroyMap()
  }

  modalBackdropClick(event) {
    if (event.target === this.modalTarget) this.close(event)
  }

  useCurrentLocation(event) {
    event?.preventDefault()
    if (!("geolocation" in navigator)) return
    navigator.geolocation.getCurrentPosition(
      (pos) => this.#placeMarker(pos.coords.latitude, pos.coords.longitude, { fly: true }),
      () => { /* sin permiso, sigue manual */ },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    )
  }

  confirm(event) {
    event?.preventDefault()
    if (this.selected) {
      this.latitudeFieldTarget.value = this.selected.lat
      this.longitudeFieldTarget.value = this.selected.lng
      this.#renderSummary()
    }
    this.close()
  }

  clear(event) {
    event?.preventDefault()
    this.latitudeFieldTarget.value = ""
    this.longitudeFieldTarget.value = ""
    this.selected = null
    this.#renderSummary()
  }

  // ---------- helpers ----------

  #initMap() {
    if (this.map) {
      this.map.resize()
      return
    }
    this.#injectMapLibreCss()

    const start = this.#initialCenter()
    this.map = new maplibregl.Map({
      container: this.mapContainerTarget,
      style: this.#osmStyle(),
      center: [start.lng, start.lat],
      zoom: start.fromInput ? 14 : 11
    })

    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right")
    this.map.addControl(new maplibregl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
      trackUserLocation: false
    }), "top-right")

    this.map.on("click", (e) => this.#placeMarker(e.lngLat.lat, e.lngLat.lng))
    this.map.on("load", () => {
      if (start.fromInput) this.#placeMarker(start.lat, start.lng, { fly: false })
    })
  }

  #destroyMap() {
    if (this.marker) { this.marker.remove(); this.marker = null }
    if (this.map) { this.map.remove(); this.map = null }
  }

  #initialCenter() {
    const lat = parseFloat(this.latitudeFieldTarget.value)
    const lng = parseFloat(this.longitudeFieldTarget.value)
    if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
      return { lat, lng, fromInput: true }
    }
    return { lat: -33.5571, lng: -71.6065, fromInput: false } // Cartagena (Chile)
  }

  #placeMarker(lat, lng, { fly = false } = {}) {
    this.selected = { lat, lng }

    if (!this.marker) {
      const el = document.createElement("div")
      el.style.cssText = "width:22px;height:22px;border-radius:9999px;background:#7c3aed;border:3px solid #fff;box-shadow:0 0 0 2px rgba(124,58,237,.35);transform:translate(-50%,-50%);"
      this.marker = new maplibregl.Marker({ element: el, draggable: true })
        .setLngLat([lng, lat])
        .addTo(this.map)
      this.marker.on("dragend", () => {
        const p = this.marker.getLngLat()
        this.selected = { lat: p.lat, lng: p.lng }
        this.#renderCoords()
      })
    } else {
      this.marker.setLngLat([lng, lat])
    }

    if (fly) this.map.flyTo({ center: [lng, lat], zoom: Math.max(this.map.getZoom(), 14), essential: true })

    this.#renderCoords()
    this.confirmBtnTarget.disabled = false
    this.confirmBtnTarget.classList.remove("opacity-50", "cursor-not-allowed")
  }

  #renderCoords() {
    if (!this.hasCoordsTarget || !this.selected) return
    this.coordsTarget.textContent = `${this.selected.lat.toFixed(5)}, ${this.selected.lng.toFixed(5)}`
  }

  #renderSummary() {
    if (!this.hasSummaryTarget) return
    const lat = this.latitudeFieldTarget.value
    const lng = this.longitudeFieldTarget.value
    if (lat && lng) {
      this.summaryTarget.textContent = `📍 ${parseFloat(lat).toFixed(5)}, ${parseFloat(lng).toFixed(5)}`
      this.summaryTarget.classList.remove("text-neutral-500")
      this.summaryTarget.classList.add("text-violet-700", "font-medium")
    } else {
      this.summaryTarget.textContent = "Sin ubicación elegida"
      this.summaryTarget.classList.add("text-neutral-500")
      this.summaryTarget.classList.remove("text-violet-700", "font-medium")
    }
  }

  #osmStyle() {
    return {
      version: 8,
      sources: {
        osm: {
          type: "raster",
          tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
          tileSize: 256,
          attribution: "© OpenStreetMap contributors"
        }
      },
      layers: [{ id: "osm", type: "raster", source: "osm" }]
    }
  }

  #injectMapLibreCss() {
    if (document.querySelector('link[data-maplibre]')) return
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = "https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css"
    link.dataset.maplibre = "true"
    document.head.appendChild(link)
  }
}
