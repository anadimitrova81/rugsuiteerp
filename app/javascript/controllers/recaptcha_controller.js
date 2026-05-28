import { Controller } from "@hotwired/stimulus"

// Fetches a v3 reCAPTCHA token before submitting the form.
// The grecaptcha script is loaded by the application layout (always present
// when a site key is configured), so we just wait for the global to be ready,
// time out gracefully if it isn't, and submit anyway on failure — the server
// will surface the standard error banner instead of the button looking dead.
const READY_TIMEOUT_MS = 5000
const EXECUTE_TIMEOUT_MS = 10000

export default class extends Controller {
  static targets = ["token"]
  static values = { siteKey: String, action: String }

  connect() {
    this.submitting = false
    this.element.addEventListener("submit", this.handleSubmit)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.handleSubmit)
  }

  handleSubmit = (event) => {
    if (this.submitting) return

    event.preventDefault()

    this.fetchToken()
      .then((token) => {
        this.tokenTarget.value = token
        this.submit()
      })
      .catch((err) => {
        console.error("[recaptcha]", err)
        this.submit()
      })
  }

  submit() {
    this.submitting = true
    this.element.requestSubmit()
  }

  fetchToken() {
    return this.waitForGrecaptcha().then(
      () =>
        new Promise((resolve, reject) => {
          const timer = setTimeout(
            () => reject(new Error("grecaptcha.execute timed out")),
            EXECUTE_TIMEOUT_MS,
          )
          window.grecaptcha.ready(() => {
            window.grecaptcha
              .execute(this.siteKeyValue, { action: this.actionValue || "submit" })
              .then(
                (token) => {
                  clearTimeout(timer)
                  resolve(token)
                },
                (err) => {
                  clearTimeout(timer)
                  reject(err)
                },
              )
          })
        }),
    )
  }

  waitForGrecaptcha() {
    return new Promise((resolve, reject) => {
      if (window.grecaptcha && window.grecaptcha.execute) return resolve()

      const start = Date.now()
      const interval = setInterval(() => {
        if (window.grecaptcha && window.grecaptcha.execute) {
          clearInterval(interval)
          resolve()
        } else if (Date.now() - start > READY_TIMEOUT_MS) {
          clearInterval(interval)
          reject(new Error("grecaptcha did not load in time"))
        }
      }, 100)
    })
  }
}
