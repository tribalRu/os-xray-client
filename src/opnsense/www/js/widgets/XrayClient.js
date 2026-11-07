/*
 * Xray Client dashboard widget for os-xray-client.
 *
 * Shows every configured Xray outbound node with its state, latency and
 * traffic. It reuses the plugin's own API, so nothing else has to be changed:
 *   /api/xrayclient/settings/searchNode  node list (name, protocol, address ...)
 *   /api/xrayclient/service/stats        per-node traffic counters
 *   /api/xrayclient/service/healthcheck  per-node TCP connect latency
 *   /api/xrayclient/service/status       service running/stopped
 */

export default class XrayClient extends BaseWidget {
    constructor(config) {
        super(config);

        // Traffic and service state are refreshed on every tick (seconds).
        this.tickTimeout = 30;

        // The latency probe is a TCP connect test run through configd and can
        // take a few seconds, so it runs on its own slower timer, the same
        // 5 minute interval the plugin page uses.
        this.latencyInterval = 300000;
        this.latencyUpdatedAt = 0;
        this.latencyInFlight = false;

        this.nodes = [];
        this.stats = {};
        this.latency = {};
        this.running = null;
        this.nodesError = false;
    }

    getGridOptions() {
        return {
            // Scroll inside the widget after 650px of height.
            sizeToContent: 650
        };
    }

    getMarkup() {
        return $('<div id="xray-widget" style="padding: 0 4px;"></div>');
    }

    async onWidgetTick() {
        const [nodesRes, statsRes, svcRes] = await Promise.allSettled([
            this.ajaxCall('/api/xrayclient/settings/searchNode', {rowCount: 999, current: 1}),
            this.ajaxCall('/api/xrayclient/service/stats'),
            this.ajaxCall('/api/xrayclient/service/status')
        ]);

        this.nodesError = nodesRes.status !== 'fulfilled' || !nodesRes.value || !Array.isArray(nodesRes.value.rows);
        if (!this.nodesError) {
            this.nodes = nodesRes.value.rows;
        }
        if (statsRes.status === 'fulfilled' && statsRes.value && statsRes.value.stats) {
            this.stats = statsRes.value.stats;
        }
        if (svcRes.status === 'fulfilled' && svcRes.value && svcRes.value.status) {
            this.running = svcRes.value.status === 'running';
        }

        this._render();

        // Do not block the first paint on the slow probe.
        if (Date.now() - this.latencyUpdatedAt >= this.latencyInterval) {
            this._refreshLatency();
        }
    }

    async _refreshLatency() {
        if (this.latencyInFlight) {
            return;
        }
        this.latencyInFlight = true;
        try {
            const res = await this.ajaxCall('/api/xrayclient/service/healthcheck');
            if (res && res.nodes) {
                this.latency = res.nodes;
                this.latencyUpdatedAt = Date.now();
                this._render();
            }
        } catch (e) {
            // Keep the previous values, retry on the next tick.
        } finally {
            this.latencyInFlight = false;
        }
    }

    _render() {
        $('#xray-widget').html(this._buildHtml());
    }

    /* Pure helpers, no DOM access. */

    _esc(value) {
        return String(value === undefined || value === null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    _bytes(bytes) {
        bytes = Number(bytes);
        if (!bytes || bytes <= 0) {
            return '0 B';
        }
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), sizes.length - 1);
        return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
    }

    // Same thresholds as the plugin page: <150 ms good, <350 ms slow.
    _latencyClass(ms) {
        return ms < 150 ? 'success' : (ms < 350 ? 'warning' : 'danger');
    }

    _latencyPill(node, info) {
        if (node.enabled !== '1') {
            return `<span class="label label-default">${this._esc(this.translations.disabled)}</span>`;
        }
        if (!info) {
            return `<span class="label label-default">${this._esc(this.translations.unchecked)}</span>`;
        }
        if (info.status !== 'online') {
            return `<span class="label label-danger">${this._esc(this.translations.offline)}</span>`;
        }
        return `<span class="label label-${this._latencyClass(info.ms)}">${parseInt(info.ms, 10)} ms</span>`;
    }

    _tile(label, value) {
        return `<div style="flex: 1; min-width: 0; background: rgba(128,128,128,0.12); border-radius: 4px; padding: 6px 10px;">
            <div style="font-size: 11px; opacity: 0.7;">${this._esc(label)}</div>
            <div style="font-size: 16px; font-weight: 600; white-space: nowrap;">${value}</div>
        </div>`;
    }

    _buildHtml() {
        const t = this.translations;

        if (this.nodesError) {
            return `<a href="/ui/xrayclient">${this._esc(t.error)}</a>`;
        }
        if (this.nodes.length === 0) {
            return `<a href="/ui/xrayclient">${this._esc(t.unconfigured)}</a>`;
        }

        const enabledNodes = this.nodes.filter(n => n.enabled === '1');
        let totalDown = 0;
        let totalUp = 0;
        let best = null;
        enabledNodes.forEach(n => {
            const s = this.stats[n.uuid];
            if (s) {
                totalDown += Number(s.downlink) || 0;
                totalUp += Number(s.uplink) || 0;
            }
            const l = this.latency[n.uuid];
            if (l && l.status === 'online' && (best === null || l.ms < best)) {
                best = l.ms;
            }
        });

        let svcLabel = '';
        if (this.running === true) {
            svcLabel = `<span class="label label-success">${this._esc(t.running)}</span>`;
        } else if (this.running === false) {
            svcLabel = `<span class="label label-danger">${this._esc(t.stopped)}</span>`;
        }

        let html = `<div style="display: flex; align-items: center; justify-content: space-between; margin: 4px 0 8px;">
            <span>${svcLabel}</span>
            <span style="font-size: 12px; opacity: 0.8;">${enabledNodes.length} / ${this.nodes.length} ${this._esc(t.active)}</span>
        </div>`;

        html += `<div style="display: flex; gap: 8px; margin-bottom: 8px;">
            ${this._tile(t.best_latency, best === null ? '&mdash;' : parseInt(best, 10) + ' ms')}
            ${this._tile(t.download, this._bytes(totalDown))}
            ${this._tile(t.upload, this._bytes(totalUp))}
        </div>`;

        this.nodes.forEach(node => {
            const enabled = node.enabled === '1';
            const info = this.latency[node.uuid];
            const st = this.stats[node.uuid] || {downlink: 0, uplink: 0};
            const noTraffic = !(Number(st.downlink) > 0) && !(Number(st.uplink) > 0);

            let dotClass = 'text-muted';
            if (enabled) {
                dotClass = this.running === false ? 'text-warning' : 'text-success';
            }

            const tags = [node.protocol, node.network, node.security, node.port]
                .filter(v => v !== undefined && v !== null && String(v) !== '')
                .map(v => `<span class="label label-default" style="font-weight: normal;">${this._esc(String(v).toUpperCase())}</span>`)
                .join(' ');

            let bar = '';
            if (enabled && info && info.status === 'online') {
                const pct = Math.max(4, Math.min(100, Math.round(info.ms / 600 * 100)));
                bar = `<div style="height: 3px; margin-top: 8px; border-radius: 2px; background: rgba(128,128,128,0.2);">
                    <div class="progress-bar-${this._latencyClass(info.ms)}" style="height: 3px; border-radius: 2px; width: ${pct}%;"></div>
                </div>`;
            }

            html += `<div style="padding: 10px 0; border-top: 1px solid rgba(128,128,128,0.25);${enabled ? '' : ' opacity: 0.6;'}">
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                    <div style="min-width: 0;">
                        <i class="fa fa-circle ${dotClass}" style="font-size: 11px;"></i>&nbsp;
                        <a href="/ui/xrayclient" style="font-weight: 600;">${this._esc(node.name)}</a>
                    </div>
                    ${this._latencyPill(node, info)}
                </div>
                <div style="margin: 3px 0 0 18px; font-size: 12px; opacity: 0.75; word-break: break-all;">${this._esc(node.address)}</div>
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px; margin: 6px 0 0 18px;">
                    <div>${tags}</div>
                    <div style="font-size: 12px; white-space: nowrap;${noTraffic ? ' opacity: 0.6;' : ''}">
                        <i class="fa fa-arrow-down"></i> ${this._bytes(st.downlink)}
                        &nbsp;<i class="fa fa-arrow-up"></i> ${this._bytes(st.uplink)}
                    </div>
                </div>
                ${bar}
            </div>`;
        });

        return html;
    }
}
