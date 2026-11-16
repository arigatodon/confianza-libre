import { Controller } from "@hotwired/stimulus"

// Suscribe este navegador a las notificaciones push.
// - connect(): si el permiso ya fue dado, renueva la suscripción en silencio.
// - enable(): pide el permiso (requiere gesto del usuario) y suscribe.
// El botón se oculta cuando no hay clave VAPID o el navegador no soporta push.
export default class extends Controller {
  static targets = ["button", "hint"]
  static values  = { vapidKey: String }

  connect() {
    if (!this.supported()) {
      this.hideButton()
      return
    }
    if (Notification.permission === "granted") {
      this.subscribe()
      this.markEnabled()
    } else if (Notification.permission === "denied") {
      this.markBlocked()
    }
  }

  async enable() {
    if (!this.supported()) return
    const permission = await Notification.requestPermission()
    if (permission === "granted") {
      await this.subscribe()
      this.markEnabled()
    } else if (permission === "denied") {
      this.markBlocked()
    }
  }

  async subscribe() {
    try {
      const registration = await navigator.serviceWorker.register("/service-worker")
      await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidKeyValue)
      })
      const { endpoint, keys } = subscription.toJSON()
      await fetch("/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ endpoint: endpoint, p256dh: keys.p256dh, auth: keys.auth })
      })
    } catch (e) {
      console.warn("[push] no se pudo suscribir:", e)
    }
  }

  supported() {
    return this.vapidKeyValue &&
           "serviceWorker" in navigator &&
           "PushManager" in window &&
           "Notification" in window
  }

  markEnabled() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.querySelector("[data-label]").textContent = "Avisos activados en este dispositivo"
    }
  }

  markBlocked() {
    if (this.hasHintTarget) {
      this.hintTarget.classList.remove("hidden")
    }
  }

  hideButton() {
    if (this.hasButtonTarget) this.buttonTarget.classList.add("hidden")
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64  = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)))
  }
}
