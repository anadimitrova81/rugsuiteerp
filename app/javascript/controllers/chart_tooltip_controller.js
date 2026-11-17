import { Controller } from "@hotwired/stimulus"

// Hover/focus readout for the server-drawn SVG column charts. Each column's
// hit area carries data-title and data-rows ([{ label, value, color }]); the
// tooltip lists every row with the value first, keyed by a short stroke of
// the series colour. Built with textContent — labels are data, not markup.
export default class extends Controller {
  static targets = ["frame", "tooltip"]

  show(event) {
    const hit = event.currentTarget
    this.activeHit?.classList.remove("is-active")
    this.activeHit = hit
    hit.classList.add("is-active")

    const tooltip = this.tooltipTarget
    tooltip.replaceChildren()

    const title = document.createElement("div")
    title.className = "client-chart-tooltip-title"
    title.textContent = hit.dataset.title
    tooltip.append(title)

    for (const row of JSON.parse(hit.dataset.rows)) {
      const line = document.createElement("div")
      line.className = "client-chart-tooltip-row"

      const key = document.createElement("span")
      key.className = "client-chart-tooltip-key"
      if (row.color) key.style.background = row.color
      const value = document.createElement("strong")
      value.textContent = row.value
      const label = document.createElement("span")
      label.className = "client-chart-tooltip-label"
      label.textContent = row.label

      line.append(key, value, label)
      tooltip.append(line)
    }

    tooltip.hidden = false
    this.position(hit)
  }

  hide(event) {
    if (event.currentTarget !== this.activeHit) return
    this.activeHit.classList.remove("is-active")
    this.activeHit = null
    this.tooltipTarget.hidden = true
  }

  // Beside the hovered column, at the top of the plot: to its right, or to
  // its left when that would run past the visible frame. The frame scrolls
  // sideways (and so clips), so the tooltip must stay inside it.
  position(hit) {
    const frameEl = this.frameTarget
    const frame = frameEl.getBoundingClientRect()
    const box = hit.getBoundingClientRect()
    const tooltip = this.tooltipTarget
    const gap = 8
    const visibleRight = frameEl.scrollLeft + frameEl.clientWidth

    let left = box.right - frame.left + frameEl.scrollLeft + gap
    if (left + tooltip.offsetWidth > visibleRight) {
      left = box.left - frame.left + frameEl.scrollLeft - tooltip.offsetWidth - gap
    }

    tooltip.style.left = `${Math.max(left, frameEl.scrollLeft)}px`
    tooltip.style.top = `${box.top - frame.top + gap}px`
  }
}
