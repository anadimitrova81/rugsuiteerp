import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "position"]
  static values = { reorderUrl: String }

  connect() {
    this.sortables = this.listTargets.map((list) =>
      Sortable.create(list, {
        animation: 150,
        group: "route-planner",   // same group across all lanes → cross-lane drag
        handle: ".route-planner-handle",
        ghostClass: "route-planner-item-ghost",
        dragClass: "route-planner-item-drag",
        onEnd: (event) => this.handleDrop(event),
      })
    )
    this.listTargets.forEach((list) => this.renumber(list))
  }

  disconnect() {
    this.sortables?.forEach((s) => s.destroy())
  }

  async handleDrop(event) {
    const fromList = event.from
    const toList = event.to

    if (fromList !== toList) {
      // Cross-lane move: persist both sides so positions stay sequential.
      await Promise.all([this.persistLane(fromList), this.persistLane(toList)])
    } else {
      await this.persistLane(toList)
    }
  }

  async persistLane(list) {
    this.renumber(list)
    const laneId = list.dataset.laneId || ""
    const ids = Array.from(list.querySelectorAll("[data-stop-id]"))
      .map((el) => el.dataset.stopId)

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    await fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrf || "",
      },
      body: JSON.stringify({ lane: laneId, ordered_ids: ids }),
    })
  }

  renumber(list) {
    list.querySelectorAll('[data-route-planner-target="position"]').forEach((el, i) => {
      el.textContent = i + 1
    })
  }
}
