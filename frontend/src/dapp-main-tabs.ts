import { LitElement, html, unsafeCSS } from 'lit';
import { customElement, property } from 'lit/decorators.js';
import { classMap } from 'lit/directives/class-map.js';

import dappMainTabsStyles from './dapp-main-tabs.component.css?inline';
import { ifTrue } from './utils.js';

@customElement('dapp-main-tabs')
class DappMainTabs extends LitElement {
    @property() activeTab = 'deposit';

    override render() {
        const tabNames = {
            'deposit': 'Deposit',
            'settings': 'Settings'
        };
        const topTabs = [];
        const tabContent = [];
        for( const [tn,tt] of Object.entries(tabNames) ) {
            const isActive = this.activeTab == tn;
            const tc = {'active': isActive};
            topTabs.push(html`
                <li role="presentation">
                    <button id="${tn}-tab"
                            class=${classMap(tc)}
                            @click=${()=>this.set(tn)}
                            type="button"
                            role="tab"
                            aria-controls="panel-${tn}"
                            aria-selected="${isActive?'true':'false'}">
                        ${tt}
                    </button>
                </li>
            `);
            tabContent.push(html`
                <div id="panel-${tn}" class=${ifTrue(isActive,'active')} role="tabpanel" aria-labelledby="${tn}-tab">
                    ${tt}
                </div>
            `);
        }

        return html`
            <div id="topTabs">
                <ul role="tablist">
                    ${topTabs}
                </ul>
            </div>
            <div id="tabContent">
                ${tabContent}
            </div>
        `;
    }

    public set (tabName:string) {
        this.activeTab = tabName;
    }

    static override styles = unsafeCSS(dappMainTabsStyles);
}

export { DappMainTabs }
