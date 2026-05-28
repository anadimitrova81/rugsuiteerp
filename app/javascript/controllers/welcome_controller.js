import { Controller } from "@hotwired/stimulus"

// Drives the post-signup onboarding modal:
//   - shows step 1 by default
//   - Back / Next advance between steps
//   - on the last step, the Next button is hidden and Close + Login appear
//   - dismissal is remembered in localStorage so it doesn't re-appear
export default class extends Controller {
  static targets = ["overlay", "step", "back", "next", "close", "login", "indicator"]
  static values = {
    storageKey: { type: String, default: "rugsuite:welcome:dismissed" },
  }

  connect() {
    if (window.localStorage?.getItem(this.storageKeyValue)) {
      this.dismiss()
      return
    }
    this.currentStep = 0
    this.render()
  }

  next(event) {
    event.preventDefault()
    if (this.currentStep < this.stepTargets.length - 1) {
      this.currentStep += 1
      this.render()
    }
  }

  back(event) {
    event.preventDefault()
    if (this.currentStep > 0) {
      this.currentStep -= 1
      this.render()
    }
  }

  close(event) {
    if (event) event.preventDefault()
    this.markDismissed()
    this.dismiss()
  }

  // When the user clicks the Login link on the final step, mark dismissed
  // (so the tour doesn't re-open after they log out). The browser handles
  // the actual navigation via the link's href — we don't preventDefault.
  markDismissedAction(_event) {
    this.markDismissed()
  }

  markDismissed() {
    try {
      window.localStorage?.setItem(this.storageKeyValue, "1")
    } catch (_) {
      // Private mode / disabled storage — best-effort only.
    }
  }

  dismiss() {
    this.overlayTarget?.remove()
  }

  // Step 2's "Show me where" button: jump-scroll to the Staff login link in
  // the footer, highlight it with a primary-color button + arrow, and HIDE
  // the modal entirely so nothing covers the link. Modal reappears after a
  // beat, or stays gone if the user clicks the link itself.
  revealLogin(event) {
    event.preventDefault()
    const link = document.querySelector(".home-footer-staff")
    if (!link) return

    this.overlayTarget.hidden = true
    link.classList.add("home-footer-staff-pulse")
    link.scrollIntoView({ behavior: "auto", block: "center" })

    window.setTimeout(() => {
      link.classList.remove("home-footer-staff-pulse")
      this.overlayTarget.hidden = false
    }, 3000)
  }

  render() {
    const isLast = this.currentStep === this.stepTargets.length - 1

    this.stepTargets.forEach((step, idx) => {
      step.hidden = idx !== this.currentStep
    })
    if (this.hasBackTarget)  this.backTarget.hidden  = this.currentStep === 0 || isLast
    if (this.hasNextTarget)  this.nextTarget.hidden  = isLast
    if (this.hasCloseTarget) this.closeTarget.hidden = !isLast
    if (this.hasLoginTarget) this.loginTarget.hidden = !isLast

    if (this.hasIndicatorTarget) {
      this.indicatorTargets.forEach((dot, idx) => {
        dot.dataset.active = idx === this.currentStep ? "true" : "false"
      })
    }
  }
}
