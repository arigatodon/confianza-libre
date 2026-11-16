import { Controller } from "@hotwired/stimulus"
import maplibregl from "maplibre-gl"

// Renderiza un mapa MapLibre + OpenStreetMap.
//
// data-map-posts-value='[{lat,lng,title,url,kind}, ...]'
// data-map-center-value='{"lat":..,"lng":..}'     (opcional)
// data-map-zoom-value=12                          (opcional)
// data-map-request-geo-value=true                 (opcional, default true)
export default class extends Controller {
  static values = {
    posts: { type: Array, default: [] },
    center: { type: Object, default: {} },
    zoom: { type: Number, default: 12 },
    requestGeo: { type: Boolean, default: true }
  }

  connect() {
    this.#injectStylesOnce()

    const center = this.#resolveCenter()
    const style = this.#defaultStyle()

    this.map = new maplibregl.Map({
      container: this.element,
      style,
      center: [center.lng, center.lat],
      zoom: this.zoomValue
    })

    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right")
    this.map.addControl(new maplibregl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
      trackUserLocation: true,
      showUserHeading: true,
      showAccuracyCircle: true
    }), "top-right")

    this.map.on("load", () => {
      this.#renderMarkers()
      if (this.requestGeoValue) this.#requestBrowserGeolocation()
    })
  }

  disconnect() {
    if (this.map) this.map.remove()
  }

  #resolveCenter() {
    if (this.centerValue && this.centerValue.lat != null && this.centerValue.lng != null) {
      return { lat: this.centerValue.lat, lng: this.centerValue.lng }
    }
    const first = this.postsValue.find(p => p.lat != null && p.lng != null)
    if (first) return { lat: first.lat, lng: first.lng }
    return { lat: -33.5571, lng: -71.6065 } // Cartagena (Chile) — centro por defecto
  }

  #defaultStyle() {
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

  #renderMarkers() {
    const bounds = new maplibregl.LngLatBounds()
    let count = 0

    this.postsValue.forEach((post) => {
      if (post.lat == null || post.lng == null) return
      const el = document.createElement("div")
      el.className = "map-marker"
      el.style.cssText = "background:#1f56a8;color:#fff;padding:4px 8px;border-radius:6px;font-size:12px;font-weight:600;border:1px solid #fff;box-shadow:0 2px 6px rgba(21,24,28,.2);max-width:160px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transform:translate(-50%,-100%);cursor:pointer;"
      el.textContent = post.title || "·"

      const popup = new maplibregl.Popup({ offset: 16, closeButton: false }).setHTML(
        `<div style="font-family:inherit;font-size:12px;line-height:1.3;max-width:200px">
           <div style="font-weight:600;margin-bottom:2px">${this.#escape(post.title || "")}</div>
           <div style="color:#4a4f57;text-transform:uppercase;letter-spacing:.06em;font-weight:700;font-size:10px;margin-bottom:6px">${this.#escape(post.kind || "")}</div>
           ${post.url ? `<a href="${post.url}" data-turbo-frame="_top" style="color:#1f56a8;text-decoration:underline;font-weight:600">Ver publicación</a>` : ""}
         </div>`
      )

      new maplibregl.Marker({ element: el })
        .setLngLat([post.lng, post.lat])
        .setPopup(popup)
        .addTo(this.map)

      bounds.extend([post.lng, post.lat])
      count += 1
    })

    if (count > 1) {
      this.map.fitBounds(bounds, { padding: 48, maxZoom: 14, duration: 0 })
    }
  }

  #requestBrowserGeolocation() {
    if (!("geolocation" in navigator)) return
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude } = pos.coords
        this.#placeUserMarker(latitude, longitude)
        this.map.flyTo({ center: [longitude, latitude], zoom: Math.max(this.map.getZoom(), 13), essential: true })
        this.#persist(latitude, longitude)
      },
      () => { /* sin permiso: usamos el centro por defecto */ },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    )
  }

  #placeUserMarker(lat, lng) {
    if (this.userMarker) this.userMarker.remove()
    const dot = document.createElement("div")
    dot.style.cssText = "width:18px;height:18px;border-radius:9999px;background:#ffc629;border:4px solid #1f56a8;box-shadow:0 0 0 3px rgba(255,255,255,.9);"
    this.userMarker = new maplibregl.Marker({ element: dot })
      .setLngLat([lng, lat])
      .setPopup(new maplibregl.Popup({ offset: 14, closeButton: false }).setText("Estás aquí"))
      .addTo(this.map)
  }

  #persist(latitude, longitude) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch("/geolocation", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ latitude, longitude })
    }).catch(() => {})
  }

  #escape(str) {
    return String(str)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }

  #injectStylesOnce() {
    if (document.querySelector('link[data-maplibre]')) return
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = "https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css"
    link.dataset.maplibre = "true"
    document.head.appendChild(link)
  }
}
