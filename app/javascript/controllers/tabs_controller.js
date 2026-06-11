import { Controller } from "@hotwired/stimulus"

// Settings page tabs: shows one section panel at a time. A panel can belong to
// several tabs via a space-separated data-tab-panel.
//
// The active tab is remembered in sessionStorage so it survives the redirect
// after saving (Turbo drops the URL fragment on form-submission redirects, so
// the hash alone isn't reliable). On load we prefer an explicit hash, then the
// remembered tab, then the first tab.
const STORE_KEY = "settings-active-tab"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.show(this.initialTab())
  }

  select(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.tabName)
  }

  show(name) {
    const names = this.tabTargets.map((tab) => tab.dataset.tabName)
    if (!names.includes(name)) name = this.tabTargets[0]?.dataset.tabName
    if (!name) return

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabName === name
      tab.classList.toggle("settings-tab-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })
    this.panelTargets.forEach((panel) => {
      const owners = (panel.dataset.tabPanel || "").split(/\s+/)
      panel.hidden = !owners.includes(name)
    })

    this.remember(name)
    if (window.location.hash.replace(/^#/, "") !== name) {
      history.replaceState(null, "", `#${name}`)
    }
  }

  initialTab() {
    const hash = window.location.hash.replace(/^#/, "")
    if (hash) return hash
    return this.remembered() || this.tabTargets[0]?.dataset.tabName
  }

  remember(name) {
    try { window.sessionStorage.setItem(STORE_KEY, name) } catch (e) { /* storage unavailable */ }
  }

  remembered() {
    try { return window.sessionStorage.getItem(STORE_KEY) } catch (e) { return null }
  }
}
