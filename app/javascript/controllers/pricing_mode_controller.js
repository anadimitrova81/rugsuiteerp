import { Controller } from "@hotwired/stimulus"

// Toggles which pricing panel (per_kg vs per_sqm) is visible on the
// admin settings form based on the selected radio button.
export default class extends Controller {
  static targets = ["radio", "panel"]

  switch() {
    const selected = this.radioTargets.find((r) => r.checked)?.value
    if (!selected) return
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.pricingModeName !== selected
    })
  }
}
