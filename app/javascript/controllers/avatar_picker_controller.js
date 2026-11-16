import { Controller } from "@hotwired/stimulus"

// Picker de avatar con dos modos:
//   - Tomar foto: en mobile usa <input capture="user"> (cámara nativa).
//     En desktop abre un modal con la webcam vía getUserMedia.
//   - Examinar: file picker normal (galería / archivos).
//
// Muestra preview en vivo del archivo elegido o de la foto capturada.
export default class extends Controller {
  static targets = [
    "input", "preview",
    "modal", "video", "canvas", "error",
    "captureBtn", "retryBtn", "confirmBtn"
  ]

  connect() {
    this.inputTarget.addEventListener("change", (e) => this.#renderPreview(e.target.files?.[0]))
  }

  disconnect() {
    this.#stopStream()
  }

  takePhoto(event) {
    event.preventDefault()
    if (this.#isMobile() || !navigator.mediaDevices?.getUserMedia) {
      // Mobile: el input nativo con capture es más rápido que un modal con webcam.
      this.inputTarget.setAttribute("capture", "user")
      this.inputTarget.click()
    } else {
      // Desktop: webcam vía getUserMedia.
      this.#openWebcamModal()
    }
  }

  browse(event) {
    event.preventDefault()
    this.inputTarget.removeAttribute("capture")
    this.inputTarget.click()
  }

  async #openWebcamModal() {
    this.#showModal()
    this.#showError(null)
    this.#showCapture()
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play().catch(() => { /* autoplay no-op */ })
    } catch (err) {
      const messages = {
        NotAllowedError: "Denegaste el permiso de cámara.",
        NotFoundError:   "No hay cámara disponible.",
        NotReadableError: "La cámara está siendo usada por otra app.",
        OverconstrainedError: "La cámara no soporta esa configuración."
      }
      this.#showError(messages[err.name] || `Error: ${err.message}`)
      this.captureBtnTarget.classList.add("hidden")
    }
  }

  capture(event) {
    event.preventDefault()
    if (!this.videoTarget.videoWidth) return

    const canvas = this.canvasTarget
    // Cuadrado centrado para que combine con el avatar redondo.
    const side = Math.min(this.videoTarget.videoWidth, this.videoTarget.videoHeight)
    canvas.width = side
    canvas.height = side
    const ctx = canvas.getContext("2d")
    // Espejamos para que la foto coincida con lo que el usuario ve en pantalla.
    ctx.translate(side, 0)
    ctx.scale(-1, 1)
    const sx = (this.videoTarget.videoWidth - side) / 2
    const sy = (this.videoTarget.videoHeight - side) / 2
    ctx.drawImage(this.videoTarget, sx, sy, side, side, 0, 0, side, side)

    this.videoTarget.classList.add("hidden")
    canvas.classList.remove("hidden")
    this.#showConfirm()
  }

  retry(event) {
    event.preventDefault()
    this.canvasTarget.classList.add("hidden")
    this.videoTarget.classList.remove("hidden")
    this.#showCapture()
  }

  confirm(event) {
    event.preventDefault()
    this.canvasTarget.toBlob((blob) => {
      if (!blob) return
      const file = new File([blob], `avatar-${Date.now()}.jpg`, { type: "image/jpeg" })
      // DataTransfer es la única forma de setear input.files programáticamente.
      const dt = new DataTransfer()
      dt.items.add(file)
      this.inputTarget.files = dt.files
      this.#renderPreview(file)
      this.closeModal()
    }, "image/jpeg", 0.9)
  }

  closeModal() {
    this.#stopStream()
    this.modalTarget.classList.add("hidden")
    this.canvasTarget.classList.add("hidden")
    this.videoTarget.classList.remove("hidden")
  }

  modalBackdropClick(event) {
    if (event.target === this.modalTarget) this.closeModal()
  }

  // ----- helpers -----

  #showModal() {
    this.modalTarget.classList.remove("hidden")
  }

  #showError(message) {
    if (!this.hasErrorTarget) return
    if (message) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    } else {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }

  #showCapture() {
    this.captureBtnTarget.classList.remove("hidden")
    this.retryBtnTarget.classList.add("hidden")
    this.confirmBtnTarget.classList.add("hidden")
  }

  #showConfirm() {
    this.captureBtnTarget.classList.add("hidden")
    this.retryBtnTarget.classList.remove("hidden")
    this.confirmBtnTarget.classList.remove("hidden")
  }

  #stopStream() {
    if (this.stream) {
      this.stream.getTracks().forEach(t => t.stop())
      this.stream = null
    }
  }

  #renderPreview(file) {
    if (!file || !this.hasPreviewTarget) return
    const url = URL.createObjectURL(file)
    this.previewTarget.innerHTML =
      `<img src="${url}" alt="" class="w-16 h-16 rounded-full object-cover border border-neutral-200">`
  }

  #isMobile() {
    return ("ontouchstart" in window) &&
           window.matchMedia("(pointer: coarse)").matches
  }
}
