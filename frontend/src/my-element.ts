// SPDX-License-Identifier: Apache-2.0

import { LitElement, html, unsafeCSS } from 'lit'
import { customElement, property } from 'lit/decorators.js'
import { StoreController } from "exome/lit"

//import { BTCDeposit__factory } from './contracts'
import { providerStore, ProviderManagerStore } from './provider.js';

import myElementStyles from './my-element.component.css?inline';
import './dapp-main-tabs.js';

@customElement('provider-info')
class ProviderInfoElement extends LitElement {
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

@customElement('my-element')
export class MyElement extends LitElement {
  private readonly provider = new StoreController(this, providerStore);

  override render() {
    const { mode, providers } = this.provider.store;

    const items = [];

    for( const [,v] of providers.entries() ) {
      items.push(html`<li><provider-info .m=${v} /></li>`)
    }

    return html`
      <dapp-main-tabs />
      Mode: ${mode}<br />
      <ul>
        ${items}
      </ul>
      <div class="card">
        <button part="button">
          count is
        </button>
      </div>
    `
  }

  static override styles = unsafeCSS(myElementStyles);
}

declare global {
  interface HTMLElementTagNameMap {
    'my-element': MyElement,
    'provider-info': ProviderInfoElement
  }
}
