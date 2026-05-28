import { Controller } from "@hotwired/stimulus"

// Toggles the mobile site nav. Listens for outside clicks and Escape to close.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this._outsideHandler = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this._keyHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this._outsideHandler)
    document.addEventListener("keydown", this._keyHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideHandler)
    document.removeEventListener("keydown", this._keyHandler)
  }

  toggle() {
    this._setOpen(this.menuTarget.dataset.open !== "true")
  }

  close() {
    this._setOpen(false)
  }

  _setOpen(open) {
    this.menuTarget.dataset.open = open ? "true" : "false"
    this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
  }
}
