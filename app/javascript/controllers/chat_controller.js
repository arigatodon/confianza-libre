import { Controller } from "@hotwired/stimulus"

// Alinea los mensajes propios del viewer a la derecha y los pinta en
// primary. Re-aplica al detectar nuevos mensajes appendeados por el
// broadcast Turbo Stream.
export default class extends Controller {
  static values = { userId: Number }
  static targets = ["list"]

  connect() {
    this.applyAlignment()
    this.observer = new MutationObserver(() => this.applyAlignment())
    if (this.hasListTarget) {
      this.observer.observe(this.listTarget, { childList: true })
      this.scrollToBottom()
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  applyAlignment() {
    if (!this.hasListTarget) return
    const mine = String(this.userIdValue)
    this.listTarget.querySelectorAll("[data-msg-user-id]").forEach((row) => {
      const isMine = row.dataset.msgUserId === mine
      row.classList.toggle("justify-end", isMine)
      row.classList.toggle("justify-start", !isMine)
      const bubble = row.querySelector(".bubble")
      if (!bubble) return
      bubble.classList.toggle("bg-primary", isMine)
      bubble.classList.toggle("text-on-primary", isMine)
      bubble.classList.toggle("bg-surface-container", !isMine)
      bubble.classList.toggle("text-on-surface", !isMine)
      const username = bubble.querySelector(".username")
      if (username) username.classList.toggle("hidden", isMine)
    })
    this.scrollToBottom()
  }

  scrollToBottom() {
    if (!this.hasListTarget) return
    this.listTarget.scrollTop = this.listTarget.scrollHeight
  }
}
