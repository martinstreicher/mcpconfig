import { Controller } from '@hotwired/stimulus'

// Unmasks an environment value that looks like a credential.
export default class extends Controller {
  static targets = ['masked', 'plain']

  toggle (event) {
    const showing = this.plainTargets.some((element) => !element.classList.contains('hidden'))

    this.maskedTargets.forEach((element) => element.classList.toggle('hidden', !showing))
    this.plainTargets.forEach((element) => element.classList.toggle('hidden', showing))

    event.currentTarget.textContent = showing ? 'show' : 'hide'
  }
}
