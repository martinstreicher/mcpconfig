import { Controller } from '@hotwired/stimulus'

// Shows the half of the server form that matches the chosen transport: a local
// process needs a command, a remote one needs a URL.
export default class extends Controller {
  static targets = ['remote', 'select', 'stdio']
  static values = { selected: String }

  connect () {
    this.toggle(this.selectedValue || this.selectTarget.value)
  }

  select () {
    this.toggle(this.selectTarget.value)
  }

  toggle (transport) {
    const remote = transport === 'http' || transport === 'sse'

    this.stdioTargets.forEach((element) => element.classList.toggle('hidden', remote))
    this.remoteTargets.forEach((element) => element.classList.toggle('hidden', !remote))
  }
}
