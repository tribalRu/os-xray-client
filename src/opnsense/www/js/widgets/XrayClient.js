/*
 * Xray Client dashboard widget for os-xray-client.
 *
 * Shows every configured Xray outbound node with its state, latency and
 * traffic. It reuses the plugin's own API, so nothing else has to be changed:
 *   /api/xrayclient/settings/searchNode  node list (name, protocol, address ...)
 *   /api/xrayclient/service/stats        per-node traffic counters
 *   /api/xrayclient/service/healthcheck  per-node TCP connect latency
 *   /api/xrayclient/service/status       service running/stopped
 *   /api/xrayclient/service/balancerInfo outbound each balancer selects now
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
        this.balancers = [];
        this.running = null;
        this.nodesError = false;
        this.refreshInFlight = false;

        // Live traffic mode: cheap client-side deltas on top of the
        // cumulative counters returned by /service/stats. Paused while the
        // tab is hidden; configurable from the dashboard edit mode.
        this.configurable = true;
        this.liveTimer = null;
        this.liveSample = null;      // { time: ms, stats: {uuid: {uplink, downlink}} }
        this.nodeRates = {};         // uuid -> { down, up } bytes per second
        this.liveConfig = { live: true, intervalMs: 2000 };
    }

    async onVisibilityChanged(visible) {
        if (visible) {
            await this._startLive();
        } else {
            this._stopLive();
        }
    }

    async getWidgetOptions() {
        const t = this.translations;
        return {
            live: {
                title: t.live,
                type: 'select',
                // The 26.7 widget options form only supports
                // select/select_multiple/text/textarea — no checkbox.
                options: [
                    {value: '1', label: t.live_on},
                    {value: '0', label: t.live_off}
                ],
                default: '1'
            },
            liveInterval: {
                title: t.live_interval,
                type: 'select',
                options: [
                    {value: '2', label: '2 seconds'},
                    {value: '5', label: '5 seconds'},
                    {value: '10', label: '10 seconds'},
                    {value: '30', label: '30 seconds'}
                ],
                default: '2'
            }
        };
    }

    async onWidgetOptionsChanged(options) {
        this.liveConfig = this._resolveLiveConfig(options);
        await this._startLive();
    }

    _resolveLiveConfig(cfg) {
        const live = cfg && cfg.live !== false && cfg.live !== '0';
        const secs = parseInt(cfg && cfg.liveInterval, 10);
        const intervalMs = (isNaN(secs) ? 2 : Math.min(30, Math.max(1, secs))) * 1000;
        return {live, intervalMs};
    }

    async _readLiveConfig() {
        try {
            const stored = await this.getWidgetConfig();
            return this._resolveLiveConfig(stored || {});
        } catch (e) {
            return {live: true, intervalMs: 2000};
        }
    }

    async _startLive() {
        this._stopLive();
        const cfg = await this._readLiveConfig();
        this.liveConfig = cfg;
        if (!cfg.live) {
            return;
        }
        if (typeof document !== 'undefined' && document.hidden) {
            return;
        }
        this.liveTimer = setInterval(() => this._liveTick(), cfg.intervalMs);
    }

    _stopLive() {
        if (this.liveTimer !== null) {
            clearInterval(this.liveTimer);
            this.liveTimer = null;
        }
    }

    async _liveTick() {
        if (document.hidden) {
            return;
        }
        try {
            const res = await this.ajaxCall('/api/xrayclient/service/stats');
            if (!res || !res.stats) {
                return;
            }
            this._accumulateRates(res.stats);
            this.stats = res.stats;
            this._render();
        } catch (e) {
            // Keep the previous values; next tick retries.
        }
    }

    _accumulateRates(stats) {
        const now = Date.now();
        const prev = this.liveSample;
        this.liveSample = {time: now, stats};
        if (!prev) {
            return;
        }
        const dt = (now - prev.time) / 1000;
        if (dt <= 0.4) {
            return;
        }
        const rates = {};
        for (const uuid of Object.keys(stats)) {
            const cur = stats[uuid] || {};
            const old = prev.stats[uuid];
            if (!old) {
                continue;
            }
            rates[uuid] = {
                down: Math.max(0, (parseInt(cur.downlink || 0, 10) - parseInt(old.downlink || 0, 10)) / dt),
                up: Math.max(0, (parseInt(cur.uplink || 0, 10) - parseInt(old.uplink || 0, 10)) / dt)
            };
        }
        this.nodeRates = rates;
    }

    _rate(bytesPerSec) {
        if (!isFinite(bytesPerSec) || bytesPerSec <= 0) {
            return '0 B/s';
        }
        const sizes = ['B', 'KB', 'MB', 'GB'];
        let i = 0, v = bytesPerSec;
        while (v >= 1024 && i < sizes.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? v.toFixed(0) : v.toFixed(1)) + ' ' + sizes[i] + '/s';
    }

    onWidgetClose() {
        this._stopLive();
        super.onWidgetClose();
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

    // The widget title navigates to the plugin's Overview page on click;
    // the refresh handle triggers an immediate tick (plus a latency probe,
    // regardless of the 5 minute timer).
    async onMarkupRendered() {
        const title = document.getElementById(`${this.id}-title`);
        if (title) {
            title.style.cursor = 'pointer';
            title.setAttribute('title', this.translations.open_overview);
            title.addEventListener('click', () => {
                window.location.assign('/ui/xrayclient');
            });
            const header = title.parentElement;
            // The system corner is taken by OPNsense's own link icon, so the
            // refresh handle goes inline with the title text instead: right
            // after the bold label, same line, with a small gap.
            if (header && !title.querySelector('.xray-refresh-handle')) {
                const bold = title.querySelector('b') || title;
                const handle = document.createElement('span');
                handle.className = 'xray-refresh-handle';
                handle.id = `refresh-handle-${this.id}`;
                handle.title = this.translations.refresh;
                handle.style.cssText = 'cursor: pointer; margin-left: 10px; opacity: 0.75; font-size: 12px; font-weight: normal; vertical-align: middle;';
                handle.innerHTML = '<i class="fa fa-fw fa-refresh"></i>';
                handle.setAttribute('role', 'button');
                handle.setAttribute('tabindex', '0');
                const trigger = (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    this._manualRefresh();
                };
                handle.addEventListener('click', trigger);
                handle.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        trigger(e);
                    }
                });
                bold.after(handle);
            }
        }
    }

    async _manualRefresh() {
        if (this.refreshInFlight) {
            return;
        }
        this.refreshInFlight = true;
        const icon = document.querySelector(`#refresh-handle-${this.id} i`);
        if (icon) {
            icon.classList.add('fa-spin');
        }
        this.latencyUpdatedAt = 0;
        try {
            await this.onWidgetTick();
        } finally {
            if (icon) {
                icon.classList.remove('fa-spin');
            }
            this.refreshInFlight = false;
        }
    }

    async onWidgetTick() {
        const [nodesRes, statsRes, svcRes, balRes] = await Promise.allSettled([
            this.ajaxCall('/api/xrayclient/settings/searchNode', {rowCount: 999, current: 1}),
            this.ajaxCall('/api/xrayclient/service/stats'),
            this.ajaxCall('/api/xrayclient/service/status'),
            this.ajaxCall('/api/xrayclient/service/balancerInfo')
        ]);

        this.nodesError = nodesRes.status !== 'fulfilled' || !nodesRes.value || !Array.isArray(nodesRes.value.rows);
        if (!this.nodesError) {
            this.nodes = nodesRes.value.rows;
        }
        if (statsRes.status === 'fulfilled' && statsRes.value && statsRes.value.stats) {
            this.stats = statsRes.value.stats;
            // Seed the live baseline so the first rate arrives after one interval.
            this.liveSample = {time: Date.now(), stats: statsRes.value.stats};
        }
        if (svcRes.status === 'fulfilled' && svcRes.value && svcRes.value.status) {
            this.running = svcRes.value.status === 'running';
        }

        // Only balancers Xray could answer for and that already have a pick.
        this.balancers = [];
        if (balRes.status === 'fulfilled' && balRes.value && Array.isArray(balRes.value.balancers)) {
            this.balancers = balRes.value.balancers.filter(
                b => b && b.status === 'ok' && Array.isArray(b.selecting) && b.selecting.length > 0
            );
        }

        this._render();

        // Live rates ticking when the tab is visible; slow first sample.
        if (this.liveTimer === null && this.liveConfig.live) {
            await this._startLive();
        }

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
        if (info.status === 'n/a') {
            return `<span class="label label-default">n/a</span>`;
        }
        if (info.status !== 'online') {
            return `<span class="label label-danger">${this._esc(this.translations.offline)}</span>`;
        }
        return `<span class="label label-${this._latencyClass(info.ms)}">${parseInt(info.ms, 10)} ms</span>`;
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
        let totalRateDown = 0;
        let totalRateUp = 0;
        let rateAvailable = false;
        enabledNodes.forEach(n => {
            const s = this.stats[n.uuid];
            if (s) {
                totalDown += Number(s.downlink) || 0;
                totalUp += Number(s.uplink) || 0;
            }
            const rate = this.nodeRates[n.uuid];
            if (rate) {
                totalRateDown += rate.down;
                totalRateUp += rate.up;
                rateAvailable = true;
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

        // One header line: service state, active count and total traffic.
        const headerTraffic = rateAvailable
            ? `<i class="fa fa-arrow-down"></i> ${this._rate(totalRateDown)}&nbsp;&nbsp;<i class="fa fa-arrow-up"></i> ${this._rate(totalRateUp)}`
            : `<i class="fa fa-arrow-down"></i> ${this._bytes(totalDown)}&nbsp;&nbsp;<i class="fa fa-arrow-up"></i> ${this._bytes(totalUp)}`;
        const headerTrafficTitle = `${this._esc(t.total_traffic)}: ↓ ${this._bytes(totalDown)} / ↑ ${this._bytes(totalUp)} · ${this._esc(t.best_latency)}: ${best === null ? '-' : parseInt(best, 10) + ' ms'}`;
        let html = `<div style="display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 2px 8px; margin: 2px 0 4px; font-size: 12px;">
            <span>${svcLabel} <span style="opacity: 0.8;">${enabledNodes.length}/${this.nodes.length} ${this._esc(t.active)}</span></span>
            <span style="white-space: nowrap; opacity: 0.8;" title="${headerTrafficTitle}">
                ${headerTraffic}
            </span>
        </div>`;

        // One line per balancer: which node it routes through right now.
        const nodeNames = {};
        this.nodes.forEach(n => { nodeNames['node_' + n.uuid] = n.name; });
        this.balancers.forEach(b => {
            const picked = b.selecting.map(tag => this._esc(nodeNames[tag] || tag)).join(', ');
            html += `<div style="font-size: 11px; margin: 0 0 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${this._esc(b.tag)}">
                <i class="fa fa-random" style="opacity: 0.7;"></i> <span style="opacity: 0.75;">${this._esc(b.tag)} &rarr;</span> <b>${picked}</b>
            </div>`;
        });

        this.nodes.forEach(node => {
            const enabled = node.enabled === '1';
            const info = this.latency[node.uuid];
            const st = this.stats[node.uuid] || {downlink: 0, uplink: 0};
            const noTraffic = !(Number(st.downlink) > 0) && !(Number(st.uplink) > 0);

            let dotClass = 'text-muted';
            if (enabled) {
                dotClass = this.running === false ? 'text-warning' : 'text-success';
            }

            // Protocol, transport and security as one muted word group.
            const tags = [node.protocol, node.network, node.security]
                .filter(v => v !== undefined && v !== null && String(v) !== '')
                .map(v => this._esc(String(v).toUpperCase()))
                .join(' &middot; ');
            const hostPort = this._esc(node.address) + (node.port ? ':' + this._esc(node.port) : '');

            // Rate once a second live sample exists; otherwise cumulative.
            const rate = this.nodeRates[node.uuid];
            const trafficRateCell = rate
                ? `<i class="fa fa-arrow-down"></i> ${this._rate(rate.down)}&nbsp;&nbsp;<i class="fa fa-arrow-up"></i> ${this._rate(rate.up)}`
                : `<i class="fa fa-arrow-down"></i> ${this._bytes(st.downlink)}&nbsp;&nbsp;<i class="fa fa-arrow-up"></i> ${this._bytes(st.uplink)}`;

            let bar = '';
            if (enabled && info && info.status === 'online') {
                const pct = Math.max(4, Math.min(100, Math.round(info.ms / 600 * 100)));
                bar = `<div style="height: 2px; margin-top: 4px; border-radius: 1px; background: rgba(128,128,128,0.2);">
                    <div class="progress-bar-${this._latencyClass(info.ms)}" style="height: 2px; border-radius: 1px; width: ${pct}%;"></div>
                </div>`;
            }

            html += `<div style="padding: 5px 0 6px; border-top: 1px solid rgba(128,128,128,0.25);${enabled ? '' : ' opacity: 0.6;'}">
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                    <div style="min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                        <i class="fa fa-circle ${dotClass}" style="font-size: 9px;"></i>&nbsp;
                        <a href="/ui/xrayclient" style="font-weight: 600;">${this._esc(node.name)}</a>
                        <span style="font-size: 11px; opacity: 0.65;">&nbsp;${tags}</span>
                    </div>
                    ${this._latencyPill(node, info)}
                </div>
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px; margin: 1px 0 0 15px; font-size: 11px;">
                    <span style="min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; opacity: 0.75;" title="${hostPort}">${hostPort}</span>
                    <span style="white-space: nowrap;${noTraffic ? ' opacity: 0.6;' : ''}" title="${this._esc(t.total_traffic)}: ↓ ${this._bytes(st.downlink)} / ↑ ${this._bytes(st.uplink)}">
                        ${trafficRateCell}
                    </span>
                </div>
                ${bar}
            </div>`;
        });

        return html;
    }
}
