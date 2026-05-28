import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { storageKey: String }

  connect() {
    if (this.#stored()) {
      this.element.remove()
      return
    }
    this.element.hidden = false
    requestAnimationFrame(() => this.element.classList.add("is-visible"))
  }

  accept() {
    this.#save("accepted")
    this.#dismiss()
  }

  reject() {
    this.#save("rejected")
    this.#dismiss()
  }

  #stored() {
    try {
      return localStorage.getItem(this.storageKeyValue)
    } catch {
      return null
    }
  }

  #save(value) {
    try {
      localStorage.setItem(this.storageKeyValue, value)
    } catch {
      // storage may be unavailable (e.g. private mode); silently ignore
    }
  }

  #dismiss() {
    this.element.classList.remove("is-visible")
    this.element.classList.add("is-leaving")
    const remove = () => this.element.remove()
    this.element.addEventListener("transitionend", remove, { once: true })
    setTimeout(remove, 400)
  }
}
