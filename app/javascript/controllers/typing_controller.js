import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// Indicador "X está escribiendo…" para el chat de una Interaction.
//
// Emite eventos `start` cuando el viewer empieza a tipear y `stop` después de
// IDLE_MS sin actividad o al enviar. Recibe eventos del otro participante y
// muestra/oculta el indicador con auto-hide defensivo si nunca llega un stop.
//
// HTML esperado:
//   data-controller="typing"
//   data-typing-interaction-id-value="42"
//   data-typing-viewer-id-value="7"
//   data-typing-target="input"      en el text_field
//   data-typing-target="indicator"  en el div del indicador
//   data-typing-target="label"      donde se mete el username del otro
//   data-action="submit->typing#submit" en el form
const IDLE_MS  = 2000   // tras 2s sin tipear, emito stop
const HIDE_MS  = 4000   // si no llega stop, auto-oculto a los 4s

export default class extends Controller {
  static values  = { interactionId: Number, viewerId: Number }
  static targets = ["input", "indicator", "label"]

  connect() {
    this.typingActive = false
    this.idleTimer    = null
    this.hideTimer    = null

    this.subscription = consumer.subscriptions.create(
      { channel: "TypingChannel", interaction_id: this.interactionIdValue },
      {
        received: (data) => this.#onReceived(data)
      }
    )

    if (this.hasInputTarget) {
      this.inputTarget.addEventListener("input", this.onInput)
      this.inputTarget.addEventListener("blur",  this.onBlur)
    }
  }

  disconnect() {
    this.#clearTimers()
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener("input", this.onInput)
      this.inputTarget.removeEventListener("blur",  this.onBlur)
    }
    this.subscription?.unsubscribe()
  }

  // ---- Emisores ----

  onInput = () => {
    if (!this.inputTarget.value || this.inputTarget.value.length === 0) {
      this.#emitStop()
      return
    }
    if (!this.typingActive) {
      this.typingActive = true
      this.subscription?.perform("start")
    }
    this.#bumpIdleTimer()
  }

  onBlur = () => {
    this.#emitStop()
  }

  submit() {
    this.#emitStop()
  }

  // ---- Receptor ----

  #onReceived(data) {
    if (!data || data.user_id === this.viewerIdValue) return
    if (data.event === "start") {
      this.#show(data.username)
    } else if (data.event === "stop") {
      this.#hide()
    }
  }

  #show(username) {
    if (!this.hasIndicatorTarget) return
    if (this.hasLabelTarget && username) {
      this.labelTarget.textContent = `@${username} está escribiendo…`
    }
    this.indicatorTarget.classList.remove("hidden")
    clearTimeout(this.hideTimer)
    this.hideTimer = setTimeout(() => this.#hide(), HIDE_MS)
  }

  #hide() {
    if (!this.hasIndicatorTarget) return
    this.indicatorTarget.classList.add("hidden")
    clearTimeout(this.hideTimer)
  }

  #bumpIdleTimer() {
    clearTimeout(this.idleTimer)
    this.idleTimer = setTimeout(() => this.#emitStop(), IDLE_MS)
  }

  #emitStop() {
    if (!this.typingActive) return
    this.typingActive = false
    clearTimeout(this.idleTimer)
    this.subscription?.perform("stop")
  }

  #clearTimers() {
    clearTimeout(this.idleTimer)
    clearTimeout(this.hideTimer)
  }
}
