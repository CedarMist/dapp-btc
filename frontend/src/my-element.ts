// SPDX-License-Identifier: Apache-2.0

import { LitElement, html, unsafeCSS } from 'lit'
import { customElement, property } from 'lit/decorators.js'
import { BTCDeposit__factory } from './contracts'
import { StoreController } from "exome/lit"
import { counter } from './store.js';

import { providerStore, ProviderManagerStore } from './provider.js';

import styles from './my-element.component.css?inline';

@customElement('provider-info')
export class ProviderInfoElement extends LitElement {
  @property()
  public m!: ProviderManagerStore;
  public k!: StoreController<ProviderManagerStore>;
  override connectedCallback() {
    this.k = new StoreController(this, this.m)
    super.connectedCallback()
  }
  override render() {
    const { connected, chainName, info, accounts } = this.k.store;
    return html`
      <img src=${info.icon} width=32 /> chain:${chainName} ${connected}: ${info.name}
      ${connected ? '' : html`
        <button @click=${this.m.connect}>Connect</button>
      `}
      <ul>
        ${accounts && html`
        <ul>
          ${accounts.map((x) => html `
            <li>
              ${x}
            </li>
          `)}
        </ul>
        `}
      </ul>
    `;
  }
}

/**
 * An example element.
 *
 * @slot - This element has a slot
 * @csspart button - The button
 */
@customElement('my-element')
export class MyElement extends LitElement {
  /**
   * Copy for the read the docs hint.
   */
  @property()
  docsHint = 'Click on the Vite and Lit logos to learn more'

  private readonly counter = new StoreController(this, counter);

  private readonly provider = new StoreController(this, providerStore);

  override render() {
    const { count } = this.counter.store;

    const { isEIP1193, isEIP6963, providers } = this.provider.store;

    const items = [];

    for( const [,v] of providers.entries() ) {
      items.push(html`<li><provider-info .m=${v} /></li>`)
    }

    return html`
      <slot></slot>
      Mode: ${isEIP1193 ? 'EIP-1193' : ''} ${isEIP6963 ? 'EIP-6963' : ''}<br />
      <ul>
        ${items}
      </ul>
      <div class="card">
        <button @click=${this._onClick} part="button">
          count is ${count}
        </button>
      </div>
      <p class="read-the-docs">${this.docsHint}</p>
    `
  }

  private async _onClick() {
    const { increment } = this.counter.store;
    increment();
    const x = BTCDeposit__factory.connect('0x0');
    const y = await x.getAddress();
    console.log(y);
  }

  static override styles = unsafeCSS(styles);
}

declare global {
  interface HTMLElementTagNameMap {
    'my-element': MyElement,
    'provider-info': ProviderInfoElement
  }
}
