import { Controller } from '@hotwired/stimulus'

// Validates and formats JSON in a textarea before it is ever submitted, so a
// typo is caught here rather than by the server after a round trip.
export default class extends Controller {
  static targets = ['input', 'status', 'submit']

  connect () {
    this.validate()
  }

  format () {
    const parsed = this.parse()
    if (parsed === undefined) return

    this.inputTarget.value = JSON.stringify(parsed, null, 2)
    this.validate()
  }

  parse () {
    try {
      return JSON.parse(this.inputTarget.value)
    } catch (error) {
      return undefined
    }
  }

  validate () {
    const value = this.inputTarget.value.trim()

    if (value === '') {
      this.report('Empty — this will clear every server in this scope.', 'warn')
      return
    }

    try {
      const parsed = JSON.parse(value)

      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        this.report('Expected a JSON object mapping server names to definitions.', 'error')
        return
      }

      const count = Object.keys(parsed).length
      this.report(`Valid JSON — ${count} ${count === 1 ? 'server' : 'servers'}.`, 'ok')
    } catch (error) {
      this.report(error.message, 'error')
    }
  }

  report (message, level) {
    const colors = {
      error: 'text-rose-600 dark:text-rose-400',
      ok: 'text-emerald-600 dark:text-emerald-400',
      warn: 'text-amber-600 dark:text-amber-400'
    }

    this.statusTarget.textContent = message
    this.statusTarget.className = `mt-2 text-xs ${colors[level]}`

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = level === 'error'
      this.submitTarget.classList.toggle('opacity-50', level === 'error')
    }
  }
}
