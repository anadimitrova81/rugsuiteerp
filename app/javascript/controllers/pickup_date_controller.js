import { Controller } from "@hotwired/stimulus"

// Native <input type="date"> can't disable individual days, so we reject a
// pick on a day we don't collect on: clear it and surface a message. The
// schedule (Admin → Working days) is { default: [wday…], periods: [{ from,
// to, days }] } with ISO dates; a period's days win between its dates. The
// server-side validation is the real guard; this is just nicer feedback.
export default class extends Controller {
  static values = {
    schedule: { type: Object, default: { default: [1, 2, 3, 4, 5], periods: [] } },
  }

  check() {
    const value = this.element.value
    if (!value) return

    if (this.workingDay(value)) {
      this.element.setCustomValidity("")
    } else {
      this.element.value = ""
      this.element.setCustomValidity(this.element.dataset.pickupDateMessage || "Please choose a working day.")
      this.element.reportValidity()
    }
  }

  workingDay(iso) {
    // Parse as local midnight so getDay() isn't shifted by the timezone.
    const day = new Date(`${iso}T00:00:00`).getDay() // 0 = Sun, 6 = Sat
    const period = this.scheduleValue.periods.find((p) => p.from <= iso && iso <= p.to)
    return (period ? period.days : this.scheduleValue.default).includes(day)
  }
}
