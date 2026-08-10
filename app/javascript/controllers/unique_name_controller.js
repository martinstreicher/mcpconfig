import { Controller } from '@hotwired/stimulus'

// Says while the name is still being typed that this scope already uses it,
// because saving over a name replaces the definition already sitting there. The
// server refuses that save regardless; this is only so the collision is visible
// before the round trip rather than after it.
export default class extends Controller {
  static targets = ['hint', 'input']
  static values = { taken: Array }

  connect () {
    this.defaultHint = this.hintTarget.textContent.trim()
    this.defaultClasses = this.hintTarget.className
    this.check()
  }

  check () {
    const name = this.inputTarget.value.trim()

    if (name === '' || !this.takenValue.includes(name)) {
      this.report(this.defaultHint, this.defaultClasses)
      return
    }

    this.report(
      `${name} already exists in this scope — saving replaces it.`,
      'mt-1 text-xs font-medium text-amber-600 dark:text-amber-400'
    )
  }

  report (message, classes) {
    this.hintTarget.textContent = message
    this.hintTarget.className = classes
  }
}
