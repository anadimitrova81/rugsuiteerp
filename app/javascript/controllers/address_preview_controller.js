import { Controller } from "@hotwired/stimulus"

// Two responsibilities:
//  1. Keep the "Виж проверения адрес в Google Maps" link in sync with the
//     verified-address input value.
//  2. When the verified-address field receives a Google Maps URL (paste or
//     typing), resolve it via the server and replace the field with the
//     extracted address.
export default class extends Controller {
  static targets = ["verifiedAddress", "link", "error"]
  static values = { lookupUrl: String }

  update() {
    const value = this.verifiedAddressTarget.value.trim()
    if (!this.hasLinkTarget) return
    if (value.length === 0) {
      this.linkTarget.hidden = true
      return
    }
    this.linkTarget.hidden = false
    this.linkTarget.href = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(value)}`
  }

  async maybeResolve(event) {
    const value = (event.type === "paste"
      ? (event.clipboardData || window.clipboardData).getData("text")
      : this.verifiedAddressTarget.value).trim()

    if (!/^https?:\/\//.test(value)) return

    if (event.type === "paste") event.preventDefault()
    this.#showError("")
    this.verifiedAddressTarget.disabled = true

    try {
      const result = await this.#fetchLookup(value)
      if (result.error) {
        this.#showError(result.error)
        this.verifiedAddressTarget.value = value
      } else if (result.address) {
        this.verifiedAddressTarget.value = result.address
        this.update()
      } else {
        this.#showError("Линкът не съдържа адрес.")
        this.verifiedAddressTarget.value = value
      }
    } catch (err) {
      this.#showError("Грешка при обработка на линка.")
      this.verifiedAddressTarget.value = value
    } finally {
      this.verifiedAddressTarget.disabled = false
      this.verifiedAddressTarget.focus()
    }
  }

  async #fetchLookup(url) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(this.lookupUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrf || "",
        "X-Requested-With": "XMLHttpRequest",
      },
      body: JSON.stringify({ url }),
    })
    const text = await response.text()
    try {
      return JSON.parse(text)
    } catch {
      throw new Error(`Non-JSON response (status=${response.status})`)
    }
  }

  #showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = !message
  }
}
