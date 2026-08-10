import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button']
  static values = { text: String }

  async copy () {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash('Copied')
    } catch (error) {
      this.flash('Press ⌘C')
    }
  }

  flash (message) {
    if (!this.hasButtonTarget) return

    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = message

    setTimeout(() => { this.buttonTarget.textContent = original }, 1200)
  }
}
