import { Controller } from "@hotwired/stimulus"

// Native <input type="date"> can't disable individual days, so we reject a
// weekend pick on change: clear it and surface a message. The server-side
// weekend validation is the real guard; this is just nicer client feedback.
export default class extends Controller {
  check() {
    const value = this.element.value
    if (!value) return

    // Parse as local midnight so getDay() isn't shifted by the timezone.
    const day = new Date(`${value}T00:00:00`).getDay() // 0 = Sun, 6 = Sat
    if (day === 0 || day === 6) {
      this.element.value = ""
      this.element.setCustomValidity(this.element.dataset.pickupDateMessage || "Please choose a weekday.")
      this.element.reportValidity()
    } else {
      this.element.setCustomValidity("")
    }
  }
}
