import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['item']

  close (event) {
    event.target.closest('[data-dismiss-target="item"]')?.remove()
  }
}
