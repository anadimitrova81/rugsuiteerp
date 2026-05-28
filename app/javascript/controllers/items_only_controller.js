import { Controller } from "@hotwired/stimulus"

// Hides the weight input when the "items only" checkbox is ticked, and
// clears its value so a stray weight from a prior state doesn't get saved.
export default class extends Controller {
  static targets = ["checkbox", "weightWrapper"]

  connect() {
    this.apply()
  }

  toggle() {
    this.apply()
  }

  apply() {
    const hide = this.checkboxTarget.checked
    this.weightWrapperTarget.hidden = hide
    if (hide) {
      const input = this.weightWrapperTarget.querySelector("input")
      if (input) input.value = ""
    }
  }
}
