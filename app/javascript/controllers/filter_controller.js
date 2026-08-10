import { Controller } from '@hotwired/stimulus'

// Client-side filtering for a list that is already fully rendered.
export default class extends Controller {
  static targets = ['empty', 'item', 'query']

  apply () {
    const term = this.queryTarget.value.trim().toLowerCase()
    let visible = 0

    this.itemTargets.forEach((item) => {
      const matches = term === '' || (item.dataset.filterText || '').includes(term)

      item.classList.toggle('hidden', !matches)
      if (matches) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle('hidden', visible > 0)
  }
}
