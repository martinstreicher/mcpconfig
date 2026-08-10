import { Controller } from '@hotwired/stimulus'

// Applies light/dark/system immediately, then lets the form post to the server
// so the choice survives a reload and the first paint is already correct.
export default class extends Controller {
  static values = { choice: String }

  connect () {
    this.media = window.matchMedia('(prefers-color-scheme: dark)')
    this.onSystemChange = () => this.apply(this.choiceValue)
    this.media.addEventListener('change', this.onSystemChange)

    this.apply(this.choiceValue)
  }

  disconnect () {
    this.media.removeEventListener('change', this.onSystemChange)
  }

  apply (choice) {
    const dark = choice === 'dark' || (choice === 'system' && this.media.matches)

    document.documentElement.classList.toggle('dark', dark)
    document.documentElement.dataset.theme = choice
  }

  choose (event) {
    const choice = event.params.choice
    if (!choice) return

    this.choiceValue = choice
    this.apply(choice)
  }
}
