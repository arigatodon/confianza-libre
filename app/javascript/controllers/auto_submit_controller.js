import { Controller } from "@hotwired/stimulus"

// Submitea el form al que pertenece el elemento que dispara la acción.
// Útil para selects de filtros: cambiar → buscar sin tener que apretar enter.
//
// Uso:
//   <form data-controller="auto-submit" data-turbo-frame="...">
//     <select data-action="change->auto-submit#submit">...</select>
//   </form>
export default class extends Controller {
  submit(event) {
    const form = event.target.form || this.element
    if (form && typeof form.requestSubmit === "function") {
      form.requestSubmit()
    }
  }
}
