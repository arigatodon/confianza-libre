import { Controller } from "@hotwired/stimulus"

// Muestra los campos que corresponden al tipo de propuesta elegido y
// deshabilita los demás (así no se envían ni bloquean el submit con required).
export default class extends Controller {
  static targets = ["section"]

  connect() {
    this.update()
  }

  update() {
    const kind = this.element.querySelector("input[name='proposal[kind]']:checked")?.value

    this.sectionTargets.forEach(section => {
      const active = section.dataset.kind === kind
      section.classList.toggle("hidden", !active)
      section.querySelectorAll("input, select, textarea").forEach(el => {
        el.disabled = !active
      })
    })
  }
}
