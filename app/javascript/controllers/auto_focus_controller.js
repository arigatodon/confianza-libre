import { Controller } from "@hotwired/stimulus"

// Pone foco en el campo marcado como target. Útil después de un Turbo
// Stream replace del form de mensaje.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    // preventScroll: el foco no debe mover la página (en un intercambio, lo
    // primero que hay que ver es "Ahora", no el chat del final).
    if (this.hasFieldTarget) this.fieldTarget.focus({ preventScroll: true })
  }
}
