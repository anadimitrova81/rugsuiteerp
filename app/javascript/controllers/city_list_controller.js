import { Controller } from "@hotwired/stimulus"

// A repeatable list of text inputs for the factory's service cities.
// Each row submits as factory[service_cities][]; a hidden empty input ensures
// the param is always present (so removing every row clears the list).
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const row = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(row)
    const inputs = this.listTarget.querySelectorAll("input[type=text]")
    inputs[inputs.length - 1]?.focus()
  }

  remove(event) {
    event.target.closest("[data-city-list-target='row']")?.remove()
  }
}
