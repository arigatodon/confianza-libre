import { Controller } from "@hotwired/stimulus"

// Pone foco en el campo marcado como target. Útil después de un Turbo
// Stream replace del form de mensaje.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    if (this.hasFieldTarget) this.fieldTarget.focus()
  }
}
