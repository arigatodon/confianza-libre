import { Controller } from "@hotwired/stimulus"

// Botón único de compartir: despliega un menú con dos opciones — WhatsApp
// (link armado en el ERB) y copiar el enlace al portapapeles. El menú se
// cierra con click afuera, con Escape o al elegir una opción.
export default class extends Controller {
  static targets = ["label", "menu"]
  static values = { url: String }

  alternar(event) {
    event.stopPropagation()
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  cerrar() {
    this.menuTarget.hidden = true
  }

  cerrarFuera(event) {
    if (!this.element.contains(event.target)) this.cerrar()
  }

  async copiar() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.flash("¡Link copiado!")
    } catch (e) {
      this.flash("No se pudo copiar")
    }
    this.cerrar()
  }

  flash(message) {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = message
    setTimeout(() => { this.labelTarget.textContent = original }, 2000)
  }
}
