<style>
    /* OPNsense 26 full-help sidebar squeezes the form into a narrow
       column and the dialog becomes wider than the viewport.
       Keep the dialog centred and the form readable.

       Geometry intentionally mirrors the native OPNsense dialogs:
       a 62px top margin keeps the orange title bar below the fixed
       page header (so it stays visible and draggable), while the
       content column is capped to the viewport and only the form
       area scrolls.  Do not use display:flex on .modal-dialog here:
       OPNsense drags the dialog by moving the .modal wrapper, and a
       plain block child keeps that behaviour intact. */
    #DialogNode .modal-dialog,
    #DialogRule .modal-dialog {
        width: 95%;
        max-width: 675px;
        margin: 62px auto 10px;
    }
    #DialogNode .modal-dialog .modal-content,
    #DialogRule .modal-dialog .modal-content {
        display: flex;
        flex-direction: column;
        max-height: calc(100vh - 72px);
        max-height: calc(100dvh - 72px);
    }
    /* Fill all the vertical space between the header and the footer;
       the body itself scrolls, so the dialog always fits the screen.
       Height stays auto, therefore collapsing a section shrinks the
       dialog as long as the remaining content fits the viewport. */
    #DialogNode .modal-body,
    #DialogRule .modal-body {
        flex: 1 1 auto;
        min-height: 0;
        max-height: none;
        overflow-y: auto;
        overscroll-behavior: contain;
    }
    #DialogNode .modal-header,
    #DialogRule .modal-header,
    #DialogNode .modal-footer,
    #DialogRule .modal-footer {
        flex: 0 0 auto;
    }
    #DialogNode .form-search-section,
    #DialogRule .form-search-section,
    #frm_DialogNode,
    #frm_DialogRule {
        width: 100%;
    }
    #DialogNode .modal-body .form-group,
    #DialogRule .modal-body .form-group {
        margin-bottom: 10px;
    }
    /* The import dialog shows very long vless:// links; give it room. */
    /* The result list of the endpoint search scrolls inside the dialog. */
    #DialogWarpProbe_wg .modal-body,
    #DialogWarpProbe_masque .modal-body {
        max-height: calc(100vh - 230px);
        overflow-y: auto;
    }
    #DialogImportLink .modal-dialog {
        width: 95%;
        max-width: 1100px;
    }
    #import_link_input {
        width: 100% !important;
        max-width: none !important;
        font-family: monospace;
        font-size: 12px;
    }
    /* “Show advanced fields” OFF: hide rows containing .expert_only inputs. */
    #DialogNode.optional-hidden tr:has(.expert_only),
    #DialogNode.optional-hidden div.form-group:has(.expert_only) {
        display: none !important;
    }
    /* The FinalMask sections hold nothing but advanced rows, so hide the
       whole section (header included) instead of leaving an empty one. */
    #DialogNode.optional-hidden .form-search-section.expert_section {
        display: none !important;
    }
    #frm_DialogNode .json-invalid,
    #DialogNode .json-invalid {
        outline: 2px solid #d9534f !important;
        outline-offset: 1px;
        border-color: #d9534f !important;
        border-radius: 4px;
    }
    /* Centre the row content vertically: labels sit in the middle of the
       row, not glued to the top (Bootstrap defaults td to vertical-align:
       top, which leaves labels hovering in the upper part of the input). */
    #frm_general td,
    #frm_general_dns td,
    #frm_general_obs td,
    #frm_general_route td,
    #frm_general_expert td,
    #frm_maintenance td,
    #frm_DialogNode td,
    #frm_DialogRule td,
    #frm_DialogBalancer td,
    #frm_DialogDnsServer td {
        vertical-align: middle !important;
    }
    /* Collapsible sections in the node and rule dialogs use the native
       OPNsense markup (chevron at the left, cursor pointer,
       tbody.collapsible) like the General tab; the <static> flag was
       removed from those form headers so base_form.volt renders exactly
       the same structure. Any section flagged invalid (validation error)
       auto-expands via setSectionCollapsed(). */
    #DialogNode .form-search-section.collapse-section > table > thead tr th,
    #DialogRule .form-search-section.collapse-section > table > thead tr th {
        user-select: none;
    }
    #DialogNode .form-search-section.collapse-section > table > thead tr th > div,
    #DialogRule .form-search-section.collapse-section > table > thead tr th > div {
        cursor: pointer;
    }
    #DialogNode .form-search-section.collapse-section .collapse-badge,
    #DialogRule .form-search-section.collapse-section .collapse-badge {
        display: none;
        vertical-align: middle;
    }
    #DialogNode .form-search-section.collapse-section.invalid > table > thead tr th > div,
    #DialogRule .form-search-section.collapse-section.invalid > table > thead tr th > div {
        outline: 2px solid #d9534f;
        outline-offset: 2px;
        border-radius: 3px;
    }
    #DialogNode .form-search-section.collapse-section.invalid .collapse-badge,
    #DialogRule .form-search-section.collapse-section.invalid .collapse-badge {
        display: inline-block;
        margin-left: 8px;
        font-size: 11px;
        color: #ff9999;
        background: rgba(217, 83, 79, 0.18);
        padding: 1px 6px;
        border-radius: 10px;
        vertical-align: middle;
    }
    /* Stage 1 legend for help icons: required (orange), optional (blue),
       advanced (grey). */
    .xray-help-legend {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
        padding: 6px 12px;
        border-bottom: 1px solid rgba(255,255,255,0.08);
        font-size: 11px;
        color: #b5b5b5;
    }
    /* Same legend in the modal footer: one line with Cancel/Save, flush left,
       vertically centred on the buttons. */
    #DialogNode .modal-footer,
    #DialogRule .modal-footer {
        display: flex;
        align-items: center;
    }
    .xray-help-legend--footer {
        float: none;
        margin-right: auto;
        margin-left: 8px;
        border-bottom: none;
        padding: 0;
        min-height: 0;
    }
    .xray-help-legend i.fa { margin-right: 4px; }
    .xray-help-legend .icon-required { color: #ffb72c; }
    .xray-help-legend .icon-optional { color: #5bc0de; }
    .xray-help-legend .icon-advanced { color: #9a9a9a; }
    /* Pulsing dot shown while the Live traffic mode is active. */
    /* Toolbar of the nodes tab once it has been moved into the grid's own
       action bar (left of the search box and the grid tools). */
    .actionBar #nodes_toolbar {
        float: left;
        width: auto;
        margin: 0 !important;
        padding: 0;
        display: flex;
        align-items: center;
        gap: 8px;
        flex-wrap: wrap;
    }
    .actionBar #nodes_toolbar #live_traffic_wrap {
        margin-left: 6px !important;
    }
    /* Total traffic under the nodes table: right edge shared with the pager
       and the action buttons, so they form one right-hand column. */
    #telemetry_total_row {
        text-align: right;
        margin-top: 8px;
        min-height: 1.6em;
    }
    #telemetry_total {
        display: inline-block;
        max-width: 100%;
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
    }
    .live-traffic-dot {
        display: none;
        width: 9px;
        height: 9px;
        margin-right: 6px;
        border-radius: 50%;
        background: #5cb85c;
        vertical-align: middle;
        animation: live-traffic-pulse 1.6s ease-out infinite;
    }
    .live-traffic-dot.on {
        display: inline-block;
    }
    @keyframes live-traffic-pulse {
        0%   { box-shadow: 0 0 0 0 rgba(92, 184, 92, 0.55); }
        70%  { box-shadow: 0 0 0 6px rgba(92, 184, 92, 0); }
        100% { box-shadow: 0 0 0 0 rgba(92, 184, 92, 0); }
    }
    .showhelp.help-required .fa-info-circle { color: #ffb72c !important; }
    .showhelp.help-optional .fa-info-circle { color: #5bc0de !important; }
    .showhelp.help-advanced .fa-info-circle { color: #9a9a9a !important; }
    /* Routing rule dialog: the rarely used match conditions (inbound, source,
       users, tag) follow the same toggle, including their section header. */
    #DialogRule.optional-hidden tr:has(.expert_only),
    #DialogRule.optional-hidden tr.expert_hdr,
    #DialogRule.optional-hidden div.form-group:has(.expert_only) {
        display: none !important;
    }
    /* Update buttons in the maintenance rows: level with the dropdown, and an
       empty help-block above them must not push them down. */
    #frm_maintenance td.maint_btn_cell {
        vertical-align: middle;
    }
    #frm_maintenance td.maint_btn_cell > .help-block:empty {
        display: none;
    }
    #frm_maintenance td.maint_btn_cell > .btn {
        white-space: normal;
    }
    /* Sub-navigation inside the Routing tab. */
    #routingtabs {
        margin: 10px 15px 6px 15px;
    }
    #routingtabs > li > a {
        padding: 6px 16px;
        border-radius: 3px;
        border-bottom: 2px solid transparent;
    }
    #routingtabs > li.active > a,
    #routingtabs > li.active > a:hover,
    #routingtabs > li.active > a:focus {
        border-bottom-color: #d94f00;
    }
    /* Same collapse for Optional knobs on the General Settings tab. The raw
       JSON rows carry .expert_only on their textarea, so they follow it. */
    #tab_general.optional-hidden tr:has(.expert_only),
    #tab_general.optional-hidden div.form-group:has(.expert_only),
    #tab_dns.optional-hidden tr:has(.expert_only),
    #tab_dns.optional-hidden div.form-group:has(.expert_only),
    #tab_balancers.optional-hidden tr:has(.expert_only),
    #tab_balancers.optional-hidden div.form-group:has(.expert_only),
    #tab_routing_policy.optional-hidden tr:has(.expert_only),
    #tab_routing_policy.optional-hidden div.form-group:has(.expert_only) {
        display: none !important;
    }
    /* The OPNsense base_dialog partial renders a third, 35%-wide column
       reserved for validation messages (span.help-block). When empty it
       shows up as a useless grey sidebar. Collapse it while every
       help-block is empty; it re-appears automatically as soon as a
       validation message is inserted (see MutationObserver setup). */
    /* Widen the input column and let controls fill it: core CSS caps
       form controls at max-width:348px and fixed-width bootstrap-select
       dropdowns at 348px, which looks cramped in this ~900px dialog. */
    #DialogNode colgroup > col:nth-child(2),
    #DialogRule colgroup > col:nth-child(2) {
        width: 58% !important;
    }
    #DialogNode colgroup > col:nth-child(3),
    #DialogRule colgroup > col:nth-child(3) {
        width: 17% !important;
    }
    #DialogNode .form-control,
    #DialogRule .form-control {
        max-width: none;
    }
    /* Expert/Raw JSON areas must use the full width, not the core 348px cap. */
    #tab_expert pre,
    #tab_expert textarea,
    #raw_json_container textarea,
    textarea.json_section {
        width: 100% !important;
        max-width: none !important;
    }
    textarea.json_section {
        font-family: monospace;
        font-size: 12px;
    }
    /* Raw JSON examples live in the placeholder; keep them visibly "sample
       text", not something that looks like a stored value. */
    textarea.json_section::placeholder {
        opacity: 0.45;
        font-style: italic;
    }
    /* Dropdowns in the settings forms may use the width of the text inputs
       beside them instead of cutting long option labels. */
    #frm_general .bootstrap-select > .dropdown-toggle,
    #frm_general_dns .bootstrap-select > .dropdown-toggle,
    #frm_general_route .bootstrap-select > .dropdown-toggle,
    #frm_general_obs .bootstrap-select > .dropdown-toggle .filter-option-inner-inner {
        white-space: normal;
    }
    #tab_expert .tab-pane,
    #tab_expert #expert_view_wrap,
    #tab_expert #expert_edit_wrap {
        width: 100%;
    }
    #DialogNode textarea,
    #DialogRule textarea {
        max-width: none !important;
        width: 100%;
    }
    #DialogNode .bootstrap-select,
    #DialogRule .bootstrap-select {
        width: 100% !important;
        max-width: none;
    }
    /* Straighten the dialog header: base_dialog pins .form-search with
       margin-top:-6px which pokes it above the orange strip, and the title
       sits lower than the 34px search controls. Flex row centres everything. */
    #DialogNode .modal-header,
    #DialogRule .modal-header {
        display: flex !important;
        align-items: center !important;
        gap: 10px;
        min-height: 48px;
        padding: 6px 10px !important;
    }
    #DialogNode .modal-header .model-header-icon,
    #DialogRule .modal-header .model-header-icon { order: 0; }
    #DialogNode .modal-header h4,
    #DialogRule .modal-header h4 { order: 1; flex: 1 1 auto; margin: 0 !important; }
    #DialogNode .modal-header .form-search,
    #DialogRule .modal-header .form-search {
        order: 2;
        margin: 0 !important;
        float: none !important;
        width: 230px !important;
    }
    #DialogNode .modal-header .close,
    #DialogRule .modal-header .close { order: 3; margin: 0 !important; float: none !important; }
    #DialogNode.help-collapsed colgroup > col:nth-child(3),
    #DialogRule.help-collapsed colgroup > col:nth-child(3) {
        display: none;
    }
    #DialogNode.help-collapsed tr > td:nth-child(3),
    #DialogRule.help-collapsed tr > td:nth-child(3) {
        display: none;
    }
    #DialogNode.help-collapsed colgroup > col:first-child,
    #DialogRule.help-collapsed colgroup > col:first-child {
        width: 32% !important;
    }
    #DialogNode.help-collapsed colgroup > col:nth-child(2),
    #DialogRule.help-collapsed colgroup > col:nth-child(2) {
        width: 68% !important;
    }
    /* The balancer dialog mirrors the node/rule dialog geometry. */
    #DialogBalancer .modal-dialog , #DialogDnsServer .modal-dialog {
        width: 95%;
        max-width: 675px;
        margin: 62px auto 10px;
    }
    #DialogBalancer .modal-dialog .modal-content , #DialogDnsServer .modal-dialog .modal-content {
        display: flex;
        flex-direction: column;
        max-height: calc(100vh - 72px);
        max-height: calc(100dvh - 72px);
    }
    #DialogBalancer .modal-body , #DialogDnsServer .modal-body {
        flex: 1 1 auto;
        min-height: 0;
        max-height: none;
        overflow-y: auto;
        overscroll-behavior: contain;
    }
    #DialogBalancer .modal-header, #DialogDnsServer .modal-header,
    #DialogBalancer .modal-footer , #DialogDnsServer .modal-footer {
        flex: 0 0 auto;
    }
    #DialogBalancer .form-search-section, #DialogDnsServer .form-search-section,
    #frm_DialogBalancer, #frm_DialogDnsServer {
        width: 100%;
    }
    #DialogBalancer .modal-body .form-group , #DialogDnsServer .modal-body .form-group {
        margin-bottom: 10px;
    }
    #DialogBalancer colgroup > col:nth-child(2) , #DialogDnsServer colgroup > col:nth-child(2) { width: 58% !important; }
    #DialogBalancer colgroup > col:nth-child(3) , #DialogDnsServer colgroup > col:nth-child(3) { width: 17% !important; }
    #DialogBalancer .form-control , #DialogDnsServer .form-control { max-width: none; }
    #DialogBalancer textarea , #DialogDnsServer textarea { max-width: none !important; width: 100%; }
    #DialogBalancer .bootstrap-select , #DialogDnsServer .bootstrap-select { width: 100% !important; max-width: none; }
    #DialogBalancer .modal-header , #DialogDnsServer .modal-header {
        display: flex !important;
        align-items: center !important;
        gap: 10px;
        min-height: 48px;
        padding: 6px 10px !important;
    }
    #DialogBalancer .modal-header .model-header-icon , #DialogDnsServer .modal-header .model-header-icon { order: 0; }
    #DialogBalancer .modal-header h4 , #DialogDnsServer .modal-header h4 { order: 1; flex: 1 1 auto; margin: 0 !important; }
    #DialogBalancer .modal-header .form-search , #DialogDnsServer .modal-header .form-search {
        order: 2;
        margin: 0 !important;
        float: none !important;
        width: 230px !important;
    }
    #DialogBalancer .modal-header .close , #DialogDnsServer .modal-header .close { order: 3; margin: 0 !important; float: none !important; }
    #DialogBalancer.help-collapsed colgroup > col:nth-child(3) , #DialogDnsServer.help-collapsed colgroup > col:nth-child(3) { display: none; }
    #DialogBalancer.help-collapsed tr > td:nth-child(3) , #DialogDnsServer.help-collapsed tr > td:nth-child(3) { display: none; }
    #DialogBalancer.help-collapsed colgroup > col:first-child , #DialogDnsServer.help-collapsed colgroup > col:first-child { width: 32% !important; }
    #DialogBalancer.help-collapsed colgroup > col:nth-child(2) , #DialogDnsServer.help-collapsed colgroup > col:nth-child(2) { width: 68% !important; }
</style>

<script>
    $(document).ready(function () {
        // One-time cleanups: the OPNsense 26 Tabulator wrapper persists column
        // widths to localStorage. Grids are built while their tab is hidden
        // (0-width), fitColumns then stores minimums and the persisted widths
        // win over the layout on every later load — or a previous release's
        // author widths keep winning after the markup changed. Drop the
        // persisted column definitions for our grids once per cleanup-mark.
        // Bump CLEANUP_VERSION whenever author widths (data-width attributes) change.
        (function tabulatorWidthCleanup() {
            try {
                var CLEANUP_VERSION = '7';
                if (localStorage.getItem('osxray_tabulator_cleanup') !== CLEANUP_VERSION) {
                    Object.keys(localStorage).filter(function (k) {
                        return /^tabulator-.*#grid-(nodes|rules|balancers|dns)-columns$/.test(k);
                    }).forEach(function (k) {
                        localStorage.removeItem(k);
                    });
                    localStorage.setItem('osxray_tabulator_cleanup', CLEANUP_VERSION);
                }
            } catch (e) {}
        })();

        mapDataToFormUI({
            'frm_general': "/api/xrayclient/settings/get",
            'frm_general_dns': "/api/xrayclient/settings/get",
            'frm_general_obs': "/api/xrayclient/settings/get",
            'frm_general_route': "/api/xrayclient/settings/get",
            'frm_general_expert': "/api/xrayclient/settings/get",
            'frm_maintenance': "/api/xrayclient/settings/get"
        }).done(function (data) {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            toggleConfigModeUI();
            toggleGeoDataCustomUI();
            setupPluginBranchPicker();
            startTelemetryAutoRefresh();
            if (typeof toggleExpertTab === 'function') {
                toggleExpertTab(expertTabWanted());
            }
            toggleGeneralRows();
        });

        updateServiceControlUI('xrayclient');

        // Collapse the empty 35%-wide validation column (span.help-block)
        // in the node/rule dialogs. It re-appears automatically when a
        // validation message is inserted (watched by MutationObserver).
        (function setupHelpBlockCollapse() {
            function refresh($dialog) {
                var anyContent = false;
                $dialog.find('span.help-block').each(function () {
                    if ($.trim($(this).text()) !== '' || $(this).children().length > 0) {
                        anyContent = true;
                        return false;
                    }
                });
                $dialog.toggleClass('help-collapsed', !anyContent);
            }
            $('#DialogNode, #DialogRule, #DialogBalancer, #DialogDnsServer').each(function () {
                var $dialog = $(this);
                refresh($dialog);
                var observer = new MutationObserver(function () {
                    refresh($dialog);
                });
                observer.observe(this, { childList: true, subtree: true, characterData: true });
                $dialog.on('shown.bs.modal', function () {
                    refresh($dialog);
                });
            });
        })();

        // Built-in rule presets in the Add/Edit rule dialog (instead of
        // memorising sequences by hand). The preset box lives outside the
        // generated <form>, so it is never submitted with the form.
        (function setupRulePresets() {
            var presets = {
                lan_private: { sequence: 10, description: 'Bypass Local & Private Subnets (geoip:private)', domain: [], ip: ['geoip:private'], outbound_tag: 'direct' },
                ru_domains: { sequence: 20, description: 'Bypass Russian Domains (geosite:ru + .ru/.рф)', domain: ['geosite:ru', 'domain:ru', 'domain:xn--p1ai'], ip: [], outbound_tag: 'direct' },
                ru_ips: { sequence: 30, description: 'Bypass Russian IP Ranges (geoip:ru)', domain: [], ip: ['geoip:ru'], outbound_tag: 'direct' },
                block_ads: { sequence: 90, description: 'Block Ads (geosite:category-ads-all)', domain: ['geosite:category-ads-all'], ip: [], outbound_tag: 'block' }
            };
            var $preset = $(
                '<div id="rule_preset_container" style="display:flex;align-items:center;gap:10px;padding:12px 15px;border-bottom:1px solid rgba(255,255,255,0.08);margin-bottom:5px;">' +
                    '<label for="rule_preset" style="margin:0;white-space:nowrap;"><b>Built-in preset</b></label>' +
                    '<select id="rule_preset" class="form-control" style="flex:1 1 auto;">' +
                        '<option value="">— Custom (empty form) —</option>' +
                        '<option value="lan_private">Bypass LAN / private subnets (geoip:private → direct)</option>' +
                        '<option value="ru_domains">Bypass Russian domains (geosite:ru + .ru/.рф → direct)</option>' +
                        '<option value="ru_ips">Bypass Russian IP ranges (geoip:ru → direct)</option>' +
                        '<option value="block_ads">Block ads (geosite:category-ads-all → block)</option>' +
                    '</select>' +
                '</div>'
            );
            $('#DialogRule .modal-body').prepend($preset);

            function setTokens(id, values) {
                var $sel = $('#rule\\.' + id);
                if (!$sel.length) {
                    return;
                }
                var merged = [];
                values.forEach(function (v) {
                    if (v && merged.indexOf(v) === -1) {
                        merged.push(v);
                    }
                });
                $sel.empty();
                merged.forEach(function (v) {
                    $('<option/>').val(v).text(v).prop('selected', true).appendTo($sel);
                });
                if (typeof formatTokenizersUI === 'function') {
                    formatTokenizersUI();
                }
            }

            $('#rule_preset').on('change', function () {
                var key = $(this).val();
                if (!key || !presets[key]) {
                    return;
                }
                var p = presets[key];
                // Keep the preset's usual position unless another rule already
                // uses it; then append after the last rule instead.
                var seq = p.sequence, used = [];
                try {
                    used = $('#grid-rules').bootgrid('getCurrentRows').map(function (r) { return parseInt(r.sequence, 10); });
                } catch (e) {
                    used = [];
                }
                if (used.indexOf(seq) !== -1) {
                    seq = Math.min(9999, Math.max.apply(null, used) + 10);
                }
                $('#rule\\.enabled').prop('checked', true);
                $('#rule\\.sequence').val(seq);
                $('#rule\\.description').val(p.description);
                setTokens('domain', p.domain);
                setTokens('ip', p.ip);
                $('#rule\\.network_proto').val('tcp_udp').selectpicker('refresh');
                $('#rule\\.outbound_tag').val(p.outbound_tag).selectpicker('refresh');
            });
        })();

        // Built-in DNS server presets in the Add/Edit server dialog.
        // Mirrors the rule dialog pattern: preset box lives outside the
        // generated <form>, so it is never submitted with the form.
        (function setupDnsPresets() {
            var presets = {
                doh_cloudflare: {
                    address: 'https://1.1.1.1/dns-query', port: '', domains: [],
                    expected_ips: [], unexpected_ips: [], skip_fallback: false
                },
                doh_google: {
                    address: 'https://dns.google/dns-query', port: '', domains: [],
                    expected_ips: [], unexpected_ips: [], skip_fallback: false
                },
                doh_cloudflare_local: {
                    address: 'https+local://1.1.1.1/dns-query', port: '', domains: [],
                    expected_ips: [], unexpected_ips: [], skip_fallback: false
                },
                doh_adguard: {
                    address: 'https://dns.adguard-dns.com/dns-query', port: '', domains: [],
                    expected_ips: [], unexpected_ips: [], skip_fallback: false
                },
                ru_yandex: {
                    address: 'https://dns.yandex.ru/dns-query', port: '443',
                    domains: ['domain:ru', 'domain:xn--p1ai', 'domain:su'],
                    expected_ips: ['geoip:ru'], unexpected_ips: [], skip_fallback: true
                },
                ru_yandex_tcp: {
                    address: 'tcp://dns.yandex.ru', port: '',
                    domains: ['domain:ru', 'domain:xn--p1ai', 'domain:su'],
                    expected_ips: ['geoip:ru'], unexpected_ips: [], skip_fallback: true
                },
                localhost: {
                    address: 'localhost', port: '', domains: [],
                    expected_ips: [], unexpected_ips: [], skip_fallback: false
                }
            };
            var $preset = $(
                '<div id="dns_preset_container" style="display:flex;align-items:center;gap:10px;padding:12px 15px;border-bottom:1px solid rgba(255,255,255,0.08);margin-bottom:5px;">' +
                    '<label for="dns_preset" style="margin:0;white-space:nowrap;"><b>Built-in preset</b></label>' +
                    '<select id="dns_preset" class="form-control" style="flex:1 1 auto;">' +
                        '<option value="">— Custom (empty form) —</option>' +
                        '<option value="doh_cloudflare">Cloudflare DoH (all domains)</option>' +
                        '<option value="doh_google">Google DoH (all domains)</option>' +
                        '<option value="doh_cloudflare_local">Cloudflare DoH direct (https+local://)</option>' +
                        '<option value="doh_adguard">AdGuard DoH (all domains, ad-blocking)</option>' +
                        '<option value="ru_yandex">Yandex DoH — only .ru/.рф/.su (skipFallback, expectedIPs geoip:ru)</option>' +
                        '<option value="ru_yandex_tcp">Yandex plain DNS — only .ru/.рф/.su</option>' +
                        '<option value="localhost">System resolver (localhost)</option>' +
                    '</select>' +
                '</div>'
            );
            $('#DialogDnsServer .modal-body').prepend($preset);

            function setTokens(id, values) {
                var $sel = $('#server\\.' + id);
                if (!$sel.length) {
                    return;
                }
                var merged = [];
                values.forEach(function (v) {
                    if (v && merged.indexOf(v) === -1) {
                        merged.push(v);
                    }
                });
                $sel.empty();
                merged.forEach(function (v) {
                    $('<option/>').val(v).text(v).prop('selected', true).appendTo($sel);
                });
                if (typeof formatTokenizersUI === 'function') {
                    formatTokenizersUI();
                }
            }

            $('#dns_preset').on('change', function () {
                var key = $(this).val();
                if (!key || !presets[key]) {
                    return;
                }
                var p = presets[key];
                $('#server\\.enabled').prop('checked', true);
                $('#server\\.address').val(p.address);
                $('#server\\.port').val(p.port);
                setTokens('domains', p.domains);
                setTokens('expected_ips', p.expected_ips);
                setTokens('unexpected_ips', p.unexpected_ips);
                $('#server\\.skip_fallback').prop('checked', p.skip_fallback);
            });
        })();

        // Expert Config tab: view the effective /usr/local/etc/xray/config.json
        // or edit it manually. Saving routes through saveRawConfigAction
        // (validate -> backup -> xray run -test -> atomic write -> restart).
        // The tab is shown when the checkbox asks for it, and always in Raw JSON
        // mode (the raw config and the mode selector live there).
        window.expertTabWanted = function expertTabWanted() {
            return $('#xrayclient\\.general\\.expert_mode').prop('checked') ||
                $('#xrayclient\\.general\\.config_mode').val() === 'raw';
        };

        window.toggleExpertTab = function toggleExpertTab(show) {
            $('#tab_expert_li').toggle(!!show);
            if (!show && $('a[href="#tab_expert"]').parent().hasClass('active')) {
                $('a[href="#tab_general"]').tab('show');
            }
        };

        $('#xrayclient\\.general\\.expert_mode').on('change', function () {
            toggleExpertTab(expertTabWanted());
        });
        // Switching to Raw JSON keeps the tab; switching back never pulls it
        // away from under the user (it is re-evaluated on the next load).
        $('#xrayclient\\.general\\.config_mode').on('change', function () {
            if ($(this).val() === 'raw') {
                toggleExpertTab(true);
            }
        });

        var expertConfigLoaded = false;

        function loadExpertConfig() {
            $('#expert_config_view').text('Loading…');
            ajaxCall('/api/xrayclient/service/getConfig', {}, function (data) {
                if (data && data.status === 'ok') {
                    $('#expert_config_view').text(data.content);
                    $('#expert_config_status').text('Loaded from ' + data.path).removeClass('text-danger').addClass('text-muted');
                } else {
                    $('#expert_config_view').text('Failed to read config.json: ' + ((data && data.message) || 'unknown error'));
                    $('#expert_config_status').text('');
                }
            });
        }

        $('a[href="#tab_expert"]').on('shown.bs.tab', function () {
            if (!expertConfigLoaded) {
                expertConfigLoaded = true;
                loadExpertConfig();
            }
        });

        $('#btn_expert_refresh').on('click', loadExpertConfig);

        function expertEditing(editing) {
            $('#expert_view_wrap').toggle(!editing);
            $('#expert_edit_wrap').toggle(editing);
            $('#btn_expert_edit, #btn_expert_refresh').toggle(!editing);
            $('#btn_expert_save, #btn_expert_cancel').toggle(editing);
            $('#expert_edit_error').hide();
        }

        $('#btn_expert_edit').on('click', function () {
            $('#expert_config_edit').val($('#expert_config_view').text());
            expertEditing(true);
        });

        $('#btn_expert_cancel').on('click', function () {
            expertEditing(false);
            loadExpertConfig();
        });

        $('#btn_expert_save').on('click', function () {
            var content = $('#expert_config_edit').val();
            try {
                JSON.parse(content);
            } catch (e) {
                $('#expert_edit_error').text('Invalid JSON: ' + e.message).show();
                return;
            }
            var $btn = $(this);
            $('#expert_edit_error').hide();
            $btn.prop('disabled', true);
            $('#expert_save_spin').show();
            $('#expert_config_status').text('Saving & applying…');
            ajaxCall('/api/xrayclient/service/saveRawConfig', { content: content }, function (data) {
                $btn.prop('disabled', false);
                $('#expert_save_spin').hide();
                if (data && data.status === 'ok') {
                    $('#expert_config_status').text(data.message || 'Saved').removeClass('text-danger').addClass('text-success');
                    expertEditing(false);
                    loadExpertConfig();
                    // The model now says config_mode=raw — sync the dropdown.
                    $('#xrayclient\\.general\\.config_mode').val('raw').selectpicker('refresh');
                    updateServiceControlUI('xrayclient');
                } else {
                    $('#expert_edit_error').text((data && data.message) || 'Save failed').show();
                    $('#expert_config_status').text('');
                }
            });
        });

        $('#btn_expert_reset').on('click', function () {
            $('#DialogResetTemplate').modal('show');
        });

        $('#btn_confirm_reset_template').on('click', function () {
            var $btn = $(this);
            $btn.prop('disabled', true);
            $('#expert_config_status').text('Regenerating config from template…');
            ajaxCall('/api/xrayclient/service/resetTemplate', {}, function (data) {
                $btn.prop('disabled', false);
                $('#DialogResetTemplate').modal('hide');
                if (data && data.status === 'ok') {
                    $('#expert_config_status').text(data.message || 'Config regenerated').removeClass('text-danger').addClass('text-success');
                    expertEditing(false);
                    loadExpertConfig();
                    // The model now says config_mode=ui — sync the dropdown.
                    $('#xrayclient\\.general\\.config_mode').val('ui').selectpicker('refresh');
                    updateServiceControlUI('xrayclient');
                } else {
                    $('#expert_config_status').text((data && data.message) || 'Reset failed').removeClass('text-muted').addClass('text-danger');
                }
            });
        });

        // The Raw JSON textarea is rendered outside the generated
        // <form id="frm_general">. saveFormToEndpoint() only serialises
        // fields inside that form, so move the container inside it or
        // Raw JSON would never be saved to config.xml.
        $('#frm_general_expert').append($('#raw_json_container'));

        // The raw JSON sections are plain textareas that carry the model field
        // ids. Each one is moved into a table row at the end of the form
        // it belongs to (DNS settings on the DNS Servers tab; observatory and
        // extra balancers on the Balancers tab), so it reads like every other
        // field and, being .expert_only, only shows with "Show advanced
        // fields". They end up inside the same form as their model fields, so
        // saveFormToEndpoint() keeps picking them up.
        (function placeJsonSections() {
            var rows = [
                // [textarea id, label, row to insert after]
                ['dns_json', 'Raw JSON: <code>dns</code>', 'dns_use_system_hosts'],
                ['dns_hosts_json', 'Raw JSON: <code>dns.hosts</code>', 'dns_use_system_hosts'],
                ['observatory_json', 'Raw JSON: observatory', 'observatory_concurrency'],
                ['balancers_json', 'Raw JSON: <code>routing.balancers</code>', 'observatory_concurrency']
            ];
            var after = {};
            rows.forEach(function (r) {
                var $group = $('#xrayclient\\.general\\.' + r[0]).closest('.form-group');
                var $ta = $group.find('textarea').first();
                if ($ta.length === 0) {
                    return;
                }
                var anchorId = 'xrayclient.general.' + r[2];
                var $anchor = after[anchorId] || $('[id="' + anchorId + '"]').closest('tr');
                if ($anchor.length === 0) {
                    return;
                }
                // Same markup as every other row of the form: an info icon in the
                // label cell, and the help text hidden until the icon (or the
                // "full help" switch) shows it.
                var helpId = 'help_for_xrayclient.general.' + r[0];
                var $helpBody = $('<small></small>')
                    .html($group.find('.help-block').first().html())
                    .append('<br/><i>Raw JSON is inserted into config.json in UI Builder mode (ignored in Raw JSON mode); leave it empty to omit it. The syntax is checked here and <code>xray run -test</code> validates the result on Apply.</i>');
                var $helpDiv = $('<div class="hidden"></div>').attr('data-for', helpId).append($helpBody);
                var $icon = $('<a href="#" class="showhelp"><i class="fa fa-info-circle"></i></a>').attr('id', helpId);
                $icon.on('click', function (e) {
                    e.preventDefault();
                    e.stopPropagation();
                    $helpDiv.toggleClass('hidden');
                });
                $ta.addClass('expert_only');
                var $row = $('<tr class="json_row"></tr>')
                    .append($('<td></td>').append($('<div class="control-label"></div>').append($icon).append(' <b>' + r[1] + '</b>')))
                    .append($('<td></td>').append($ta).append($helpDiv))
                    .append($('<td></td>').append($('<span class="help-block"></span>').attr('id', 'help_block_xrayclient.general.' + r[0])));
                $anchor.after($row);
                after[anchorId] = $row;
            });
            $('#json_sections_container').remove();
        })();

        function toggleConfigModeUI() {
            var mode = $('#xrayclient\\.general\\.config_mode').val();
            if (mode === 'raw') {
                $('#raw_json_container').show();
                $('tr.json_row').hide();
            } else {
                $('#raw_json_container').hide();
                $('tr.json_row').show();
            }
        }
        $('#xrayclient\\.general\\.config_mode').on('change', toggleConfigModeUI);

        // General Settings: rows that depend on a toggle or dropdown are
        // hidden when they would not take effect. The "Show advanced fields"
        // collapse is combined through the normal CSS rule for .expert_only
        // rows; this function only toggles unrelated rows.
        function toggleGeneralRows() {
            var ids = function () { return Array.prototype.slice.call(arguments); };
            function setRow(id, show) {
                var $el = $('#xrayclient\\.general\\.' + id);
                if ($el.length === 0) { return; }
                // OPNsense 26 renders base_form rows as <tr id="row_...">;
                // older layouts use .form-group, so match both.
                $el.closest('tr, .form-group').toggle(show);
            }
            function setRows(list, show) {
                list.forEach(function (id) { setRow(id, show); });
            }

            var socksOn = !!$('#xrayclient\\.general\\.enable_socks').prop('checked');
            var httpOn = !!$('#xrayclient\\.general\\.enable_http').prop('checked');
            var tunOn = !!$('#xrayclient\\.general\\.enable_tun').prop('checked');
            var sniffOn = !!$('#xrayclient\\.general\\.enable_sniffing').prop('checked');
            var telemetryOn = !!$('#xrayclient\\.general\\.auto_telemetry').prop('checked');
            var dnsOn = !!$('#xrayclient\\.general\\.dns_enabled').prop('checked');
            var socksAuth = ($('#xrayclient\\.general\\.socks_auth').val() || 'noauth') === 'password';
            var httpAuth = ($('#xrayclient\\.general\\.http_auth').val() || 'noauth') === 'password';

            setRows(ids('socks_auth', 'socks_listen', 'socks_port'), socksOn);
            setRows(ids('socks_username', 'socks_password'), socksOn && socksAuth);

            setRows(ids('http_listen', 'http_auth', 'http_port'), httpOn);
            setRows(ids('http_username', 'http_password'), httpOn && httpAuth);

            setRows(ids('tun_iface', 'tun_address', 'tun_mtu', 'tun_ipv6_address', 'tun_auto_outbounds_interface'), tunOn);

            setRows(ids('sniffing_dest_override', 'sniffing_route_only', 'sniffing_domains_excluded'), sniffOn);

            setRows(ids('telemetry_interval'), telemetryOn);

            setRows(ids('dns_query_strategy', 'dns_disable_cache', 'dns_disable_fallback',
                        'dns_disable_fallback_if_match', 'dns_enable_parallel_query', 'dns_use_system_hosts'), dnsOn);

            // Observatory: burst and background observatories use different
            // keys, and neither key applies when the observatory is off.
            var obsType = $('#xrayclient\\.general\\.observatory_type').val() || 'none';
            ids('selector', 'url', 'interval', 'sampling', 'timeout', 'http_method', 'concurrency').forEach(function (name) {
                var show = false;
                if (obsType === 'burst') {
                    show = (name !== 'concurrency');
                } else if (obsType === 'background') {
                    show = (name === 'selector' || name === 'url' ||
                        name === 'interval' || name === 'concurrency');
                }
                setRow('observatory_' + name, show);
            });
        }
        $('#xrayclient\\.general\\.enable_socks, #xrayclient\\.general\\.enable_http, #xrayclient\\.general\\.enable_tun, #xrayclient\\.general\\.enable_sniffing, #xrayclient\\.general\\.auto_telemetry, #xrayclient\\.general\\.dns_enabled, #xrayclient\\.general\\.socks_auth, #xrayclient\\.general\\.http_auth, #xrayclient\\.general\\.observatory_type').on('change', toggleGeneralRows);

        // Each update button sits in the row of the field it acts on, in the
        // otherwise empty third column right of the dropdown.
        (function placeMaintenanceButtons() {
            [['btn_update_core', 'core_branch'], ['btn_update_geodata', 'geodata_preset'], ['btn_update_plugin', 'plugin_branch']].forEach(function (p) {
                var $btn = $('#' + p[0]);
                var $cell = $('[id="xrayclient.maintenance.' + p[1] + '"]').closest('tr').children('td').eq(2);
                if ($btn.length === 0 || $cell.length === 0) {
                    return;
                }
                $cell.addClass('maint_btn_cell').append($btn);
            });
        })();

        function toggleGeoDataCustomUI() {
            var preset = $('#xrayclient\\.maintenance\\.geodata_preset').val();
            var $rows = $('.geodata_custom').closest('tr, .form-group');
            if (preset === 'custom') {
                $rows.show();
            } else {
                $rows.hide();
            }
        }
        $('#xrayclient\\.maintenance\\.geodata_preset').on('change', toggleGeoDataCustomUI);

        // Plugin branch picker. The model field is plain text (any branch
        // name); it is hidden and replaced by a list read from GitHub, so
        // the saved value is still whatever the select holds.
        var pluginBranchLoaded = null;
        function setupPluginBranchPicker() {
            var $input = $('[id="xrayclient.maintenance.plugin_branch"]');
            if (!$input.length || $('#plugin_branch_picker').length) {
                return;
            }
            $input.hide().after(
                '<select id="plugin_branch_picker" class="selectpicker" data-live-search="true" data-width="auto" data-size="10"></select>' +
                ' <span id="plugin_branch_note" class="small"></span>'
            );
            $('#plugin_branch_picker').on('change', function () {
                $input.val($(this).val());
                renderPluginBranchState();
            });
            $input.on('input change', renderPluginBranchState);
            renderPluginBranches(null);
            refreshPluginBranches();
        }

        function renderPluginBranchState() {
            var branch = $('[id="xrayclient.maintenance.plugin_branch"]').val() || 'main';
            var $note = $('#plugin_branch_note');
            if (branch !== 'main') {
                $note.removeClass('text-muted').addClass('text-warning')
                    .text('Unmerged test branch: its code is installed as root. Switch back to main for normal use.');
            } else if (pluginBranchLoaded === false) {
                $note.removeClass('text-warning').addClass('text-muted').text('Branch list unavailable (GitHub unreachable).');
            } else {
                $note.text('');
            }
            $('#btn_update_plugin b').text(branch === 'main' ? 'Update Plugin from GitHub' : 'Install Plugin from branch ' + branch);
        }

        function renderPluginBranches(branches) {
            var $input = $('[id="xrayclient.maintenance.plugin_branch"]');
            var $sel = $('#plugin_branch_picker');
            var current = $input.val() || 'main';
            var list = (branches || []).slice();
            if (list.indexOf(current) === -1) {
                list.push(current);
            }
            if (list.indexOf('main') === -1) {
                list.unshift('main');
            }
            $sel.empty();
            list.forEach(function (name) {
                var label = name === 'main' ? 'main (stable)' : name;
                if (branches && branches.length && branches.indexOf(name) === -1) {
                    label += ' (not on GitHub)';
                }
                $('<option/>').val(name).text(label).appendTo($sel);
            });
            $sel.val(current).selectpicker('refresh');
            renderPluginBranchState();
        }

        function refreshPluginBranches() {
            ajaxCall('/api/xrayclient/service/pluginBranches', {}, function (data) {
                var $input = $('[id="xrayclient.maintenance.plugin_branch"]');
                var $picker = $('#plugin_branch_picker').closest('.bootstrap-select');
                if (data && data.status === 'ok' && $.isArray(data.branches)) {
                    pluginBranchLoaded = true;
                    renderPluginBranches(data.branches);
                    $input.hide();
                    $picker.show();
                } else {
                    // No list: fall back to typing the branch name by hand.
                    pluginBranchLoaded = false;
                    renderPluginBranches(null);
                    $picker.hide();
                    $input.show();
                }
            });
        }

        function toggleNodeDialogFields() {
            var proto = $('#node\\.protocol').val();
            var net = $('#node\\.network').val();
            var sec = $('#node\\.security').val();

            // OPNsense <=25 wraps fields in <tr>, >=26 in .form-group.
            // A <style> on a header field is applied to the wrapping
            // div.form-search-section (not to a table row), so never
            // hide the parent element blindly: doing that used to hide
            // the whole #frm_DialogNode and collapse the dialog.
            $('#frm_DialogNode').show();

            function setBlock(sel, show) {
                $(sel).each(function () {
                    var $el = $(this);
                    var $b;
                    if ($el.is('div.form-search-section, div.form-group')) {
                        $b = $el;
                    } else {
                        $b = $el.closest('tr, .form-group');
                        if ($b.length === 0) {
                            $b = $el;
                        }
                    }
                    if (show) {
                        $b.show();
                    } else {
                        $b.hide();
                    }
                });
            }

            // Compute context
            var streamProtos = ['vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http'];
            var directProtos = ['freedom', 'blackhole', 'dns', 'loopback', 'wireguard'];
            var passwordProtos = ['vless', 'vmess', 'trojan', 'shadowsocks'];
            var authProtos = ['socks', 'http', 'masque'];

            var hasStream = streamProtos.indexOf(proto) !== -1;
            var isHysteria = proto === 'hysteria';
            var isMasque = proto === 'masque';
            var hasTransport = hasStream || isHysteria || isMasque;
            var hasEndpoint = directProtos.indexOf(proto) === -1;
            var hasPassword = passwordProtos.indexOf(proto) !== -1;
            var hasAuth = authProtos.indexOf(proto) !== -1;
            var hasMux = ['vless', 'vmess', 'trojan', 'shadowsocks'].indexOf(proto) !== -1;
            var effNet = isHysteria ? 'hysteria' : (isMasque ? 'masque' : net);
            var effSec = (isHysteria || isMasque) ? 'tls' : sec;
            // XDRIVE is VLESS-only; the fields must not show for other protocols.
            var isXdrive = proto === 'vless' && effNet === 'xdrive';
            var xdrvSvc = $('#node\\.xdrive_service').val() || 'google-drive';
            // FinalMask: the raw JSON override wins over the structured rows,
            // so hide the rows while it is filled (their values are still
            // saved but the template ignores them).
            var fmRaw = $.trim($('#node\\.finalmask').val() || '') !== '';
            var fmTcp = $('#node\\.fm_tcp_type').val() || 'none';
            var fmUdp = $('#node\\.fm_udp_type').val() || 'none';
            var fmQuic = $('#node\\.fm_quic_congestion').val() || 'auto';
            // MASQUE: a custom CONNECT-IP server or the built-in Cloudflare WARP client.
            var masqueWarp = isMasque && ($('#node\\.masque_mode').val() === 'warp');
            // TCP masks belong to TCP-based transports, UDP masks and the QUIC
            // parameters to QUIC-based ones: Hysteria, MASQUE over HTTP/3
            // (no h2 in ALPN) and XHTTP over h3.
            var alpnVal = $('#node\\.alpn').val() || [];
            var alpnList = Array.isArray(alpnVal) ? alpnVal : String(alpnVal).split(',');
            var fmQuicBased = isHysteria || (isMasque && alpnList.indexOf('h2') === -1)
                || (hasStream && effNet === 'xhttp' && alpnList.indexOf('h3') !== -1);
            var fmTcpBased = !fmQuicBased && (hasStream || isMasque);

            // Field visibility table: selector -> condition
            var view = {
                '.proto_endpoint': hasEndpoint,
                '.proto_password': hasPassword,
                '.proto_auth': hasAuth && !masqueWarp,
                '.proto_vless': proto === 'vless',
                '.proto_vmess': proto === 'vmess',
                '.proto_shadowsocks': proto === 'shadowsocks',
                '.proto_wireguard': proto === 'wireguard',
                '.proto_freedom': proto === 'freedom',
                '.proto_blackhole': proto === 'blackhole',
                '.proto_dns': proto === 'dns',
                '.proto_loopback': proto === 'loopback',
                '.proto_hysteria': isHysteria,
                '.proto_masque': isMasque,
                '.proto_vless_enc': proto === 'vless' && ($('#node\\.encryption').val() || 'none').toLowerCase() !== 'none',
                '.proto_http_masque': proto === 'http' || (isMasque && !masqueWarp),
                '.masque_custom': isMasque && !masqueWarp,
                '.masque_warp': masqueWarp,
                '.proto_transport': hasTransport,
                '.transport_selector': hasStream,
                '.stream_sockopt': hasStream,
                '.stream_custom': hasStream,
                '.mux_supported': hasMux,
                // Wraps the whole Transport Settings section (host/path/grpc/xhttp rows).
                // Must match every transport shown inside: ws|xhttp|httpupgrade|grpc.
                '.net_any': hasStream && ['ws', 'xhttp', 'httpupgrade', 'grpc'].indexOf(effNet) !== -1,
                '.net_http_based': hasStream && ['ws', 'xhttp', 'httpupgrade'].indexOf(effNet) !== -1,
                '.net_xhttp': hasStream && effNet === 'xhttp',
                '.net_grpc': hasStream && effNet === 'grpc',
                '.net_ws': hasStream && effNet === 'ws',
                '.net_httpupgrade': hasStream && effNet === 'httpupgrade',
                '.net_xdrive': isXdrive,
                '.xdrive_google': isXdrive && xdrvSvc === 'google-drive',
                '.xdrive_s3': isXdrive && xdrvSvc === 's3',
                '.xdrive_template': isXdrive && xdrvSvc === 'template',
                '.sec_tls': hasTransport && effSec === 'tls',
                '.sec_tls_reality': hasTransport && (effSec === 'tls' || effSec === 'reality'),
                '.sec_reality': hasTransport && effSec === 'reality',
                // FinalMask rows: one mask per direction, built by the
                // config template. Hidden entirely while the raw override
                // is filled.
                '.fm_tcp': fmTcpBased && !fmRaw,
                '.fm_tcp_fragment': fmTcpBased && !fmRaw && fmTcp === 'fragment',
                '.fm_tcp_sudoku': fmTcpBased && !fmRaw && fmTcp === 'sudoku',
                '.fm_tcp_json': fmTcpBased && !fmRaw && (fmTcp === 'header-custom' || fmTcp === 'xmc'),
                // Hysteria2 (and XUDP/WireGuard) obfuscate over QUIC/UDP
                // and honor FinalMask like any UDP transport.
                '.fm_udp': fmQuicBased && !fmRaw,
                '.fm_udp_salamander': fmQuicBased && !fmRaw && fmUdp === 'salamander',
                '.fm_udp_gecko': fmQuicBased && !fmRaw && fmUdp === 'gecko',
                '.fm_udp_sudoku': fmQuicBased && !fmRaw && fmUdp === 'sudoku',
                '.fm_udp_udphop': fmQuicBased && !fmRaw && fmUdp === 'udphop',
                '.fm_udp_mkcp_legacy': fmQuicBased && !fmRaw && fmUdp === 'mkcp-legacy',
                '.fm_udp_xicmp': fmQuicBased && !fmRaw && fmUdp === 'xicmp',
                '.fm_udp_realm': fmQuicBased && !fmRaw && fmUdp === 'realm',
                '.fm_udp_json': fmQuicBased && !fmRaw && ['noise', 'xdns', 'header-custom'].indexOf(fmUdp) !== -1,
                '.fm_quic': fmQuicBased && !fmRaw,
                '.fm_quic_bbr': fmQuicBased && !fmRaw && fmQuic === 'bbr',
                '.fm_quic_brutal': fmQuicBased && !fmRaw && (fmQuic === 'brutal' || fmQuic === 'force-brutal'),
                '.fm_quic_window': fmQuicBased && !fmRaw
            };
            for (var sel in view) {
                if (Object.prototype.hasOwnProperty.call(view, sel)) {
                    setBlock(sel, view[sel]);
                }
            }

            // XDRIVE exists only for VLESS (the server refuses it otherwise),
            // so do not offer it for other protocols; a node switched away
            // from VLESS falls back to plain TCP.
            var $netSel = $('#node\\.network');
            var $xdriveOpt = $netSel.find('option[value="xdrive"]');
            if ($xdriveOpt.length) {
                var allowXdrive = (proto === 'vless');
                if ($xdriveOpt.prop('disabled') === allowXdrive) {
                    $xdriveOpt.prop('disabled', !allowXdrive);
                    if ($.fn.selectpicker) {
                        $netSel.selectpicker('refresh');
                    }
                }
                // native value: jQuery .val() skips a disabled selected option
                if (!allowXdrive && $netSel[0].value === 'xdrive') {
                    $netSel.val('tcp');
                    if ($.fn.selectpicker) {
                        $netSel.selectpicker('refresh');
                    }
                    $netSel.trigger('change');
                }
            }
        }

        $('#node\\.protocol, #node\\.network, #node\\.security, #node\\.encryption, #node\\.xdrive_service, #node\\.alpn').on('change', toggleNodeDialogFields);
        $('#node\\.masque_mode').on('change', toggleNodeDialogFields);
        $('#node\\.fm_tcp_type, #node\\.fm_udp_type, #node\\.fm_quic_congestion').on('change', toggleNodeDialogFields);
        // Typing into the raw override hides the structured FinalMask rows,
        // so react to every keystroke (and to a programmatic .val() change).
        $('#node\\.finalmask').on('input change', toggleNodeDialogFields);

        var nodeLatencyCache = {};
        var nodeTrafficCache = {};
        var nodeTrafficRates = {};

        function formatBytes(bytes) {
            if (!bytes || bytes <= 0) return '0 B';
            var k = 1024;
            var sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            var i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        function formatRate(bytesPerSec) {
            if (!isFinite(bytesPerSec) || bytesPerSec <= 0) return '0 B/s';
            var k = 1024;
            var sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
            var i = 0, v = bytesPerSec;
            while (v >= k && i < sizes.length - 1) {
                v /= k;
                i++;
            }
            return (i === 0 ? v.toFixed(0) : v.toFixed(1)) + ' ' + sizes[i];
        }

        // Traffic cell for the Outbound Nodes grid: live rate once per second
        // when available, cumulative otherwise. Cumulative always in tooltip.
        function renderTrafficCell(st, rate) {
            var down = parseInt((st || {}).downlink || 0, 10);
            var up = parseInt((st || {}).uplink || 0, 10);
            var title = '↓ ' + formatBytes(down) + ' / ↑ ' + formatBytes(up) + ' since Xray started';
            if (rate) {
                return '<small title="' + title + '"><span class="text-success">↓ ' + formatRate(rate.down) + '</span> / <span class="text-info">↑ ' + formatRate(rate.up) + '</span></small>';
            }
            return '<small title="' + title + '"><span class="text-success">↓ ' + formatBytes(down) + '</span> / <span class="text-info">↑ ' + formatBytes(up) + '</span></small>';
        }

        // OPNsense-native "advanced fields" switch: same icon + toggle idiom
        // and the same place as core's "full help" switch (the left, reserved
        // span of the form's first row) instead of a separate floating bar.
        // onToggle receives the new state and performs storage + class updates.
        function mountNativeAdvancedToggle(formSel, label, initial, onToggle) {
            // The full-help icon exists in every OPNsense form's first row
            // (dialogs wrap it in .form-search-section, the general page
            // does not), so locate the row via the icon itself.
            var $helpIcon = $(formSel).find('[id^="show_all_help"]').first();
            var $td = $helpIcon.length
                ? $helpIcon.closest('tr').children('td')
                : $(formSel).find('.form-search-section').first().find('> table > tbody > tr').first().children('td');
            if (!$td.length) {
                return { set: function () {}, get: function () { return !!initial; } };
            }
            var state = !!initial;
            var $icon = $('<i class="fa fa-fw"></i>');
            function setIcon(v) {
                state = !!v;
                $icon.attr('class', 'fa fa-fw ' + (state ? 'fa-toggle-on text-success' : 'fa-toggle-off text-danger'));
            }
            setIcon(state);
            var $a = $('<a href="#"></a>').on('click', function (e) {
                e.preventDefault();
                setIcon(!state);
                onToggle(state);
            });
            $a.append($icon);
            $td.children('span').first().empty().append(
                $('<i class="fa fa-eye fa-sm fa-fw text-primary"></i> '),
                $('<small></small>').text(label).append(' '),
                $a
            );
            return { set: setIcon, get: function () { return state; } };
        }

        // Collapsible sections use the native OPNsense markup and the
        // built-in delegated click handler (defined in layouts/default.volt:
        // click on the thead toggles the following tbody.collapsible and
        // swaps fa-angle-down/fa-angle-right). These helpers mirror that
        // mechanism so the initial/reapplied state, the "error" badge and
        // localStorage persistence behave identically to the General tab.
        function slugSection(text) {
            return (text || '').replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase();
        }
        function sectionDetails($sec) {
            var $thead = $sec.children('table').children('thead');
            var $div = $thead.children('tr').children('th').children('div').first();
            return {
                $tbody: $sec.children('table').children('tbody'),
                $icon: $div.children('i').first(),
                $b: $div.children('b').first(),
                label: $div.children('b').length ? $div.children('b').first().text() : 'Section'
            };
        }
        function isSectionCollapsed($sec) {
            var $tbody = $sec.children('table').children('tbody');
            var $td = $tbody.children('tr').children('td').first();
            return $tbody.css('display') === 'none'
                || ($td.length > 0 && $td.css('display') === 'none');
        }
        function setSectionCollapsed($sec, collapsed) {
            var bits = sectionDetails($sec);
            bits.$tbody.css('display', '');
            bits.$tbody.children('tr').children('td').css('display', collapsed ? 'none' : '');
            bits.$icon.removeClass('fa-angle-down fa-angle-right')
                .addClass(collapsed ? 'fa-angle-right' : 'fa-angle-down');
        }
        // Persist the collapse state of dialog sections after the native
        // (core) click handler ran. Reads happen after a tick.
        $(document).on('click', '#frm_DialogNode .collapse-section > table > thead, #frm_DialogRule .collapse-section > table > thead', function () {
            var $sec = $(this).closest('.collapse-section');
            var prefix = $sec.closest('#frm_DialogRule').length ? 'osxray_rule_collapse_' : 'osxray_node_collapse_';
            setTimeout(function () {
                try {
                    localStorage.setItem(prefix + slugSection(sectionDetails($sec).label), isSectionCollapsed($sec) ? '1' : '0');
                } catch (e) {}
            }, 0);
        });

        // What a node row of the grid means. The model keeps defaults (tcp,
        // reality, port 443) for fields a protocol does not use; showing them
        // would be misleading, so the grid goes by the protocol.
        //   none: no transport (freedom, blackhole, dns, loopback)
        //   udp: WireGuard    quic: Hysteria 2    h2 / h3: MASQUE
        //   stream: every other protocol (transport and security as saved)
        function nodeRowKind(row) {
            var proto = String(row.protocol || '').toLowerCase();
            if (['freedom', 'blackhole', 'dns', 'loopback'].indexOf(proto) !== -1) {
                return 'none';
            }
            if (proto === 'wireguard') {
                return 'udp';
            }
            if (proto === 'hysteria') {
                return 'quic';
            }
            if (proto === 'masque') {
                // The same rule as the config template: no h2 in ALPN means HTTP/3.
                var alpn = String(row.alpn || '').split(',').map(function (v) { return $.trim(v); });
                return alpn.indexOf('h2') === -1 ? 'h3' : 'h2';
            }
            return 'stream';
        }

        // Endpoint shown in the Address and Port columns: WireGuard keeps it in
        // wg_endpoint (host:port or [v6]:port), the protocols without an
        // endpoint have none.
        function nodeRowEndpoint(row) {
            var proto = String(row.protocol || '').toLowerCase();
            if (proto === 'wireguard') {
                var m = /^(\[[^\]]+\]|[^:]+):(\d+)$/.exec($.trim(row.wg_endpoint || ''));
                return m ? { host: m[1], port: m[2] } : { host: $.trim(row.wg_endpoint || ''), port: '' };
            }
            if (nodeRowKind(row) === 'none') {
                return { host: '', port: '' };
            }
            return { host: String(row.address || ''), port: String(row.port || '') };
        }

        function escHtml(v) {
            return $('<div/>').text(v).html();
        }

        // Transport as {text, title}; null where it does not apply.
        function nodeTransportInfo(row) {
            var kind = nodeRowKind(row);
            var fixed = { quic: ['QUIC', 'Hysteria 2 over QUIC'], udp: ['UDP', 'WireGuard over UDP'],
                          h2: ['HTTP/2', 'MASQUE over HTTP/2'], h3: ['HTTP/3', 'MASQUE over HTTP/3 (QUIC)'] };
            if (kind === 'none') {
                return null;
            }
            if (fixed[kind]) {
                return { text: fixed[kind][0], title: fixed[kind][1] };
            }
            var map = {
                tcp: ['TCP', 'TCP (RAW)'],
                ws: ['WS', 'WebSocket (WS)'],
                grpc: ['gRPC', 'gRPC'],
                xhttp: ['XHTTP', 'XHTTP (SplitHTTP)'],
                httpupgrade: ['HTTPUpg', 'HTTPUpgrade'],
                xdrive: ['XDRIVE', 'XDRIVE (Google Drive / S3 / template)']
            };
            var entry = map[String(row.network || '').toLowerCase()];
            return entry ? { text: entry[0], title: entry[1] } : { text: String(row.network || ''), title: '' };
        }

        // Security as text; '' where it does not apply.
        function nodeSecurityText(row) {
            var kind = nodeRowKind(row);
            if (kind === 'quic' || kind === 'h2' || kind === 'h3') {
                return 'TLS';
            }
            if (kind === 'udp' || kind === 'none') {
                return '';
            }
            return String(row.security || '');
        }

        // host:port, IPv6 hosts in brackets; '' for nodes without an endpoint.
        function nodeEndpointText(row) {
            var ep = nodeRowEndpoint(row);
            if (ep.host === '') {
                return '';
            }
            var host = ep.host;
            if (host.indexOf(':') !== -1 && host.charAt(0) !== '[') {
                host = '[' + host + ']';
            }
            return ep.port === '' ? host : host + ':' + ep.port;
        }

        $("#grid-nodes").UIBootgrid({
            search: '/api/xrayclient/settings/searchNode',
            get: '/api/xrayclient/settings/getNode/',
            set: '/api/xrayclient/settings/setNode/',
            add: '/api/xrayclient/settings/addNode/',
            del: '/api/xrayclient/settings/delNode/',
            toggle: '/api/xrayclient/settings/toggleNode/',
            options: {
                formatters: {
                    "commands": function (column, row) {
                        return '<button type="button" class="btn btn-xs btn-default command-edit bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-pencil"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-copy bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-clone"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-delete bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-trash-o"></span></button>';
                    },
                    "rowtoggle": function (column, row) {
                        if (parseInt(row[column.id], 2) === 1) {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-on text-success command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-off text-muted command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    },
                    "transport": function (column, row) {
                        var info = nodeTransportInfo(row);
                        if (info === null) {
                            return '<span class="text-muted">&mdash;</span>';
                        }
                        return info.title
                            ? '<span class="bootgrid-tooltip" title="' + info.title + '">' + escHtml(info.text) + '</span>'
                            : escHtml(info.text);
                    },
                    "nodeaddr": function (column, row) {
                        var ep = nodeRowEndpoint(row);
                        return ep.host === '' ? '<span class="text-muted">&mdash;</span>' : $('<div/>').text(ep.host).html();
                    },
                    "nodeport": function (column, row) {
                        var ep = nodeRowEndpoint(row);
                        return ep.port === '' ? '<span class="text-muted">&mdash;</span>' : $('<div/>').text(ep.port).html();
                    },
                    "nodesec": function (column, row) {
                        var text = nodeSecurityText(row);
                        return text === '' ? '<span class="text-muted">&mdash;</span>' : escHtml(text);
                    },
                    // One compact column for protocol, transport and security,
                    // e.g. "VLESS · gRPC · tls" (the node widget uses the same form).
                    "nodetype": function (column, row) {
                        var sep = ' <span class="text-muted">&middot;</span> ';
                        var parts = ['<b>' + escHtml(row.protocol || '') + '</b>'];
                        var info = nodeTransportInfo(row);
                        if (info !== null && info.text !== '') {
                            parts.push(info.title
                                ? '<span class="bootgrid-tooltip" title="' + info.title + '">' + escHtml(info.text) + '</span>'
                                : escHtml(info.text));
                        }
                        var sec = nodeSecurityText(row);
                        if (sec !== '' && sec.toLowerCase() !== 'none') {
                            parts.push(escHtml(sec));
                        }
                        return parts.join(sep);
                    },
                    "nodeendpoint": function (column, row) {
                        var text = nodeEndpointText(row);
                        return text === '' ? '<span class="text-muted">&mdash;</span>' : escHtml(text);
                    },
                    "latency": function (column, row) {
                        var info = nodeLatencyCache[row.uuid];
                        if (!info) return '<span class="label label-default">Unchecked</span>';
                        if (info.status === 'n/a') return '<span class="label label-default" title="Latency is measured with a TCP connect, which does not apply to this protocol">n/a</span>';
                        if (info.status === 'online') {
                            var color = info.ms < 150 ? 'label-success' : (info.ms < 350 ? 'label-warning' : 'label-danger');
                            return '<span class="label ' + color + '">' + info.ms + ' ms</span>';
                        }
                        return '<span class="label label-danger">Offline</span>';
                    },
                    "traffic": function (column, row) {
                        var st = nodeTrafficCache[row.uuid] || {downlink: 0, uplink: 0};
                        return renderTrafficCell(st, nodeTrafficRates[row.uuid]);
                    }
                }
            }
        });

        // Condition summary parts of a rule row; empty = matches all traffic.
        function ruleMatchParts(row) {
            function list(v) {
                return String(v || '').split(',').map(function (x) { return $.trim(x); }).filter(Boolean);
            }
            var parts = [];
            var domains = list(row.domain);
            if (domains.length) {
                parts.push('domains: ' + domains.length);
            }
            var ips = list(row.ip);
            var geoip = ips.filter(function (x) { return x.indexOf('geoip:') === 0; }).length;
            if (geoip) {
                parts.push('geoip: ' + geoip);
            }
            var plain = ips.length - geoip;
            if (plain) {
                parts.push('ips: ' + plain);
            }
            if ($.trim(row.port || '')) {
                parts.push('port: ' + escHtml(row.port));
            }
            var sniff = list(row.protocol);
            if (sniff.length) {
                parts.push('sniff: ' + sniff.map(escHtml).join('/'));
            }
            if (row.network_proto && row.network_proto !== 'tcp_udp') {
                parts.push('net: ' + escHtml(row.network_proto));
            }
            [['inbound_tag', 'inbound'], ['source', 'src'], ['source_port', 'src port'], ['user', 'user']].forEach(function (f) {
                var items = list(row[f[0]]);
                if (items.length) {
                    parts.push(f[1] + ': ' + items.length);
                }
            });
            return parts;
        }

        // The enabled match-everything rule with a lower sequence number that
        // hides this (enabled) rule, or null. Only the rows of the current
        // page are known, which is enough for the usual short rule lists.
        function ruleShadowedBy(row) {
            if (String(row.enabled) !== '1') {
                return null;
            }
            var seq = parseFloat(row.sequence);
            var cover = null;
            try {
                $('#grid-rules').bootgrid('getCurrentRows').forEach(function (r) {
                    var rs = parseFloat(r.sequence);
                    if (r.uuid !== row.uuid && String(r.enabled) === '1' && rs < seq && ruleMatchParts(r).length === 0 &&
                        (cover === null || rs < parseFloat(cover.sequence))) {
                        cover = r;
                    }
                });
            } catch (e) {
                // grid API unavailable: no warning
            }
            return cover;
        }

        $("#grid-rules").UIBootgrid({
            search: '/api/xrayclient/settings/searchRule',
            get: '/api/xrayclient/settings/getRule/',
            set: '/api/xrayclient/settings/setRule/',
            add: '/api/xrayclient/settings/addRule/',
            del: '/api/xrayclient/settings/delRule/',
            toggle: '/api/xrayclient/settings/toggleRule/',
            options: {
                formatters: {
                    "commands": function (column, row) {
                        return '<button type="button" class="btn btn-xs btn-default command-edit bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-pencil"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-copy bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-clone"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-move-up" data-row-id="' + row.uuid + '" title="Move rule up"><span class="fa fa-fw fa-arrow-up"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-move-down" data-row-id="' + row.uuid + '" title="Move rule down"><span class="fa fa-fw fa-arrow-down"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-delete bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-trash-o"></span></button>';
                    },
                    "rowtoggle": function (column, row) {
                        if (parseInt(row[column.id], 2) === 1) {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-on text-success command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-off text-muted command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    },
                    // Condensed counts of every condition, e.g.
                    // "domains: 2 · geoip: 1 · port: 443". A rule that sits
                    // below an enabled match-everything rule is marked: it
                    // can never be reached.
                    "rulematch": function (column, row) {
                        var parts = ruleMatchParts(row);
                        var html = parts.length ? parts.join(' · ') : '<span class="text-muted">any traffic</span>';
                        var cover = ruleShadowedBy(row);
                        if (cover) {
                            html += ' <i class="fa fa-exclamation-triangle text-warning bootgrid-tooltip" title="Never reached: rule ' +
                                escHtml(String(cover.sequence)) + (cover.description ? ' (' + escHtml(cover.description) + ')' : '') +
                                ' above matches all traffic first."></i>';
                        }
                        return html;
                    },
                    // Flags a sequence number shared with another rule: the
                    // order between them is then decided by config order only.
                    "ruleseq": function (column, row) {
                        var dup = false;
                        try {
                            $('#grid-rules').bootgrid('getCurrentRows').forEach(function (r) {
                                if (r.uuid !== row.uuid && String(r.sequence) === String(row.sequence)) {
                                    dup = true;
                                }
                            });
                        } catch (e) {
                            // grid API unavailable: no warning, the number still shows
                        }
                        return dup
                            ? '<span class="text-warning" title="Another rule has the same sequence number; their relative order is not guaranteed. Use the arrows to renumber.">' + row.sequence + ' <i class="fa fa-exclamation-triangle"></i></span>'
                            : String(row.sequence);
                    }
                }
            }
        });

        $("#grid-balancers").UIBootgrid({
            search: '/api/xrayclient/settings/searchBalancer',
            get: '/api/xrayclient/settings/getBalancer/',
            set: '/api/xrayclient/settings/setBalancer/',
            add: '/api/xrayclient/settings/addBalancer/',
            del: '/api/xrayclient/settings/delBalancer/',
            toggle: '/api/xrayclient/settings/toggleBalancer/',
            options: {
                formatters: {
                    "commands": function (column, row) {
                        return '<button type="button" class="btn btn-xs btn-default command-edit bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-pencil"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-copy bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-clone"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-delete bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-trash-o"></span></button>';
                    },
                    "rowtoggle": function (column, row) {
                        if (parseInt(row[column.id], 2) === 1) {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-on text-success command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-off text-muted command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    }
                }
            }
        });

        // Live balancer selection (xray api bi): show which outbound the
        // balancer picks right now, translated to node names where possible.
        $('#btn_balancer_info').on('click', function () {
            var $btn = $(this).prop('disabled', true);
            var $out = $('#balancer_info_output').show();
            $out.html('<div class="alert alert-info"><i class="fa fa-spinner fa-pulse"></i> Asking Xray RoutingService…</div>');
            ajaxCall('/api/xrayclient/settings/searchNode', {}, function (nodesData) {
                var nodeNames = {};
                (nodesData.rows || nodesData || []).forEach(function (n) {
                    if (n.uuid) {
                        nodeNames['node_' + n.uuid] = n.name + (n['%protocol'] ? ' (' + n['%protocol'] + ')' : '');
                    }
                });
                // Node names, tags and Xray error text are data, not markup.
                function esc(value) {
                    return $('<div/>').text(String(value === undefined || value === null ? '' : value)).html();
                }
                function pretty(tag) {
                    return esc(nodeNames[tag] ? nodeNames[tag] : tag);
                }
                ajaxCall('/api/xrayclient/service/balancerInfo', {}, function (data) {
                    if (!data || !data.balancers || data.balancers.length === 0) {
                        $out.html('<div class="alert alert-warning">No enabled balancers, or Xray answered with nothing. Check that the RoutingService is listed under api.services in the generated config.</div>');
                        $btn.prop('disabled', false);
                        return;
                    }
                    var html = '<table class="table table-condensed table-bordered" style="margin-bottom:0; font-size:13px;"><thead><tr><th>Balancer</th><th>Selecting</th><th>Override</th><th>Status</th></tr></thead><tbody>';
                    data.balancers.forEach(function (b) {
                        var selecting = (b.selecting || []).map(pretty).join(', ');
                        var override = b.override ? pretty(b.override) : '&mdash;';
                        var status = b.status === 'ok' ? '<span class="label label-success">ok</span>' : '<span class="label label-danger">' + esc(b.message || 'error') + '</span>';
                        html += '<tr><td><code>' + esc(b.tag || '?') + '</code></td><td>' + (selecting || '<i>empty — waiting for the first probe</i>') + '</td><td>' + override + '</td><td>' + status + '</td></tr>';
                    });
                    html += '</tbody></table>';
                    $out.html(html);
                    $btn.prop('disabled', false);
                });
            });
        });

        // Toggle the &laquo;no DNS servers&raquo; hint based on the grid's
        // current state. Runs on tab show, on grid (re)load, after CRUD.
        function updateDnsEmptyState() {
            var count = $('#grid-dns > tbody > tr').length;
            $('#dns_empty_state').toggle(count === 0);
        }
        $('a[href="#tab_dns"]').on('shown.bs.tab', updateDnsEmptyState);
        $('#grid-dns').on('loaded.rs.jquery.bootgrid', updateDnsEmptyState);

        $("#grid-dns").UIBootgrid({
            search: '/api/xrayclient/settings/searchDnsServer',
            get: '/api/xrayclient/settings/getDnsServer/',
            set: '/api/xrayclient/settings/setDnsServer/',
            add: '/api/xrayclient/settings/addDnsServer/',
            del: '/api/xrayclient/settings/delDnsServer/',
            toggle: '/api/xrayclient/settings/toggleDnsServer/',
            options: {
                formatters: {
                    "commands": function (column, row) {
                        return '<button type="button" class="btn btn-xs btn-default command-edit bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-pencil"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-copy bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-clone"></span></button> ' +
                               '<button type="button" class="btn btn-xs btn-default command-delete bootgrid-tooltip" data-row-id="' + row.uuid + '"><span class="fa fa-fw fa-trash-o"></span></button>';
                    },
                    "rowtoggle": function (column, row) {
                        if (parseInt(row[column.id], 2) === 1) {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-on text-success command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-toggle-off text-muted command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    }
                }
            }
        });
        // DNS grid initialised: reflect the empty state right away.
        updateDnsEmptyState();

        $('#btn_open_import_modal').on('click', function () {
            $('#import_link_input').val('');
            $('#import_error_msg').hide();
            $('#DialogImportLink').modal('show');
        });

        // Data for a parsed link, applied on DialogNode shown.bs.modal.
        // Applying it immediately is racy: bootgrid's `get` response can
        // overwrite the fields after a fixed setTimeout.
        var pendingImport = null;

        function setSelectValue($el, value) {
            // Only set when the option exists (e.g. unknown fp values
            // like "randomizedAlice" must not corrupt the select).
            var found = false;
            $el.find('option').each(function () {
                if ($(this).val() === value) {
                    found = true;
                    return false;
                }
            });
            if (found) {
                $el.val(value).selectpicker('refresh');
            }
        }

        function fillTokenizeField(selector, value) {
            if (!value) {
                return;
            }
            var values = Array.isArray(value) ? value : String(value).split(',');
            var $sel = $(selector);
            if (!$sel.length) {
                return;
            }
            $sel.empty();
            values.forEach(function (v) {
                v = String(v).trim();
                if (v !== '') {
                    $('<option/>').val(v).text(v).prop('selected', true).appendTo($sel);
                }
            });
            if (typeof formatTokenizersUI === 'function') {
                formatTokenizersUI();
            }
            $('.selectpicker').selectpicker('refresh');
        }

        // Empty a tokenizer (select_multiple + tokenize). Clearing only the
        // selection leaves the tag list on screen, so drop the options and
        // let the formatter rebuild the widget from them.
        function clearTokenizeField(selector) {
            var $sel = $(selector);
            if (!$sel.length) {
                return;
            }
            $sel.empty();
            if (typeof formatTokenizersUI === 'function') {
                formatTokenizersUI();
            }
        }

        // Fixed multi-select (selectpicker with predefined options): select
        // matching options; re-add unknown stored values so legacy configs
        // round-trip instead of being silently dropped.
        function setMultiSelectValue(selector, value) {
            var $sel = $(selector);
            if (!$sel.length) {
                return;
            }
            if (!value) {
                $sel.val([]).trigger('change');
                $sel.selectpicker('refresh');
                return;
            }
            var values = (Array.isArray(value) ? value : String(value).split(',')).map(function (v) { return String(v).trim(); }).filter(Boolean);
            values.forEach(function (v) {
                var opts = $sel.find('option[value="' + v + '"]');
                if (opts.length === 0) {
                    $('<option/>').val(v).text(v).appendTo($sel);
                }
            });
            $sel.val(values).trigger('change');
            $sel.selectpicker('refresh');
        }

        function fillNodeDialog(data) {
            $('body').addClass('modal-open');
            $('#node\\.enabled').prop('checked', true);
            $('#node\\.name').val(data.name);
            setSelectValue($('#node\\.protocol'), data.protocol);
            $('#node\\.address').val(data.address);
            $('#node\\.port').val(data.port || '443');
            $('#node\\.user_uuid').val(data.user_uuid);
            $('#node\\.auth_user').val(data.auth_user);
            $('#node\\.auth_pass').val(data.auth_pass);
            $('#node\\.http_headers').val(data.http_headers);
            setSelectValue($('#node\\.flow'), data.flow);
            // Pretty-print JSON fields for readable editing in textarea
            function prettyJson(value) {
                if (!value) return '';
                try {
                    return JSON.stringify(JSON.parse(value), null, 2);
                } catch (e) {
                    return value;
                }
            }

            $('#node\\.encryption').val(data.encryption || 'none');
            $('#node\\.extra').val(prettyJson(data.extra));
            $('#node\\.email').val(data.email || '');
            setSelectValue($('#node\\.ss_method'), data.ss_method);
            setSelectValue($('#node\\.vmess_security'), data.vmess_security);
            $('#node\\.vmess_experiments').val(data.vmess_experiments);
            setSelectValue($('#node\\.network'), data.network);
            setSelectValue($('#node\\.security'), data.security);
            $('#node\\.sni').val(data.sni);
            $('#node\\.allow_insecure').prop('checked', data.allow_insecure === '1');
            setSelectValue($('#node\\.fingerprint'), data.fingerprint);
            setMultiSelectValue('#node\\.alpn', data.alpn);
            $('#node\\.tls_verify_peer_cert_by_name').val(data.tls_verify_peer_cert_by_name);
            $('#node\\.tls_pinned_peer_cert_sha256').val(data.tls_pinned_peer_cert_sha256);
            $('#node\\.tls_ech_config_list').val(data.tls_ech_config_list);
            $('#node\\.tls_min_version').val(data.tls_min_version);
            $('#node\\.tls_max_version').val(data.tls_max_version);
            $('#node\\.reality_pubkey').val(data.reality_pubkey);
            $('#node\\.reality_shortid').val(data.reality_shortid);
            $('#node\\.reality_spiderx').val(data.reality_spiderx);
            $('#node\\.reality_mldsa65_verify').val(data.reality_mldsa65_verify);
            $('#node\\.transport_host').val(data.transport_host);
            $('#node\\.transport_path').val(data.transport_path);
            $('#node\\.grpc_service_name').val(data.grpc_service_name);
            $('#node\\.grpc_authority').val(data.grpc_authority);
            $('#node\\.grpc_user_agent').val(data.grpc_user_agent);
            $('#node\\.grpc_idle_timeout').val(data.grpc_idle_timeout);
            $('#node\\.grpc_health_check_timeout').val(data.grpc_health_check_timeout);
            $('#node\\.grpc_initial_windows_size').val(data.grpc_initial_windows_size);
            $('#node\\.grpc_multi_mode').prop('checked', data.grpc_multi_mode == '1');
            $('#node\\.grpc_permit_without_stream').prop('checked', data.grpc_permit_without_stream == '1');
            setSelectValue($('#node\\.xhttp_mode'), data.xhttp_mode);
            $('#node\\.xhttp_extra').val(prettyJson(data.xhttp_extra));
            $('#node\\.ws_heartbeat_period').val(data.ws_heartbeat_period);
            setSelectValue($('#node\\.xdrive_service'), data.xdrive_service || 'google-drive');
            $('#node\\.xdrive_remote_folder').val(data.xdrive_remote_folder);
            $('#node\\.xdrive_google_client_id').val(data.xdrive_google_client_id);
            $('#node\\.xdrive_google_client_secret').val(data.xdrive_google_client_secret);
            $('#node\\.xdrive_google_refresh_token').val(data.xdrive_google_refresh_token);
            $('#node\\.xdrive_s3_endpoint').val(data.xdrive_s3_endpoint);
            $('#node\\.xdrive_s3_region').val(data.xdrive_s3_region);
            $('#node\\.xdrive_s3_bucket').val(data.xdrive_s3_bucket);
            $('#node\\.xdrive_s3_access_key').val(data.xdrive_s3_access_key);
            $('#node\\.xdrive_s3_secret_key').val(data.xdrive_s3_secret_key);
            $('#node\\.xdrive_s3_session_token').val(data.xdrive_s3_session_token);
            $('#node\\.xdrive_s3_path_style').prop('checked', data.xdrive_s3_path_style != '0');
            $('#node\\.xdrive_template_secrets').val(prettyJson(data.xdrive_template_secrets));
            $('#node\\.xdrive_template').val(prettyJson(data.xdrive_template));
            $('#node\\.xdrive_extra').val(prettyJson(data.xdrive_extra));
            $('#node\\.sockopt_domainStrategy').val(data.sockopt_domainStrategy || 'AsIs');
            $('#node\\.sockopt_dialer_proxy').val(data.sockopt_dialer_proxy);
            $('#node\\.sockopt_interface').val(data.sockopt_interface);

            $('#node\\.sockopt_mark').val(data.sockopt_mark);
            $('#node\\.sockopt_tcp_congestion').val(data.sockopt_tcp_congestion);
            $('#node\\.sockopt_tcp_keepalive_idle').val(data.sockopt_tcp_keepalive_idle);
            $('#node\\.sockopt_tcp_keepalive_interval').val(data.sockopt_tcp_keepalive_interval);
            $('#node\\.sockopt_tcp_user_timeout').val(data.sockopt_tcp_user_timeout);
            $('#node\\.sockopt_tcp_fast_open').prop('checked', data.sockopt_tcp_fast_open == '1');
            $('#node\\.target_strategy').val(data.target_strategy || 'AsIs');
            $('#node\\.send_through').val(data.send_through || '');
            $('#node\\.mux_concurrency').val(data.mux_concurrency || '');
            $('#node\\.finalmask').val(prettyJson(data.finalmask));
            // An imported link never carries FinalMask, so reset every
            // structured field instead of leaking values from a node that
            // was opened before.
            var fmText = [
                'fm_tcp_fragment_max_split',
                'fm_tcp_sudoku_password', 'fm_tcp_sudoku_ascii', 'fm_tcp_sudoku_padding_min',
                'fm_tcp_sudoku_padding_max', 'fm_tcp_sudoku_tables', 'fm_tcp_extra_json',
                'fm_udp_salamander_password', 'fm_udp_salamander_packet_size',
                'fm_udp_gecko_password', 'fm_udp_gecko_packet_size',
                'fm_udp_sudoku_password', 'fm_udp_sudoku_ascii', 'fm_udp_sudoku_padding_min',
                'fm_udp_sudoku_padding_max', 'fm_udp_sudoku_tables',
                'fm_udp_udphop_interval', 'fm_udp_udphop_remote_ips', 'fm_udp_udphop_remote_ports',
                'fm_udp_mkcp_value', 'fm_udp_xicmp_ips',
                'fm_udp_realm_url', 'fm_udp_realm_stun_servers', 'fm_udp_realm_ip_mode',
                'fm_udp_extra_json',
                'fm_quic_brutal_up', 'fm_quic_brutal_down', 'fm_quic_max_idle_timeout',
                'fm_quic_keep_alive_period', 'fm_quic_max_incoming_streams',
                'fm_quic_init_stream_window', 'fm_quic_max_stream_window',
                'fm_quic_init_conn_window', 'fm_quic_max_conn_window'
            ];
            $.each(fmText, function (i, id) {
                $('#node\\.' + id).val('');
            });
            clearTokenizeField('#node\\.fm_tcp_fragment_lengths');
            clearTokenizeField('#node\\.fm_tcp_fragment_delays');
            setSelectValue($('#node\\.fm_tcp_fragment_packets'), 'tlshello');
            setMultiSelectValue('#node\\.fm_udp_udphop_mode', 'intervallocal');
            $('#node\\.fm_udp_xicmp_dgram').prop('checked', false);
            $('#node\\.fm_quic_disable_pmtud').prop('checked', false);
            setSelectValue($('#node\\.fm_tcp_type'), 'none');
            setSelectValue($('#node\\.fm_udp_type'), 'none');
            setSelectValue($('#node\\.fm_udp_mkcp_header'), 'none');
            setSelectValue($('#node\\.fm_quic_congestion'), 'auto');
            setSelectValue($('#node\\.fm_quic_bbr_profile'), 'auto');
            if (data.fm_udp_type) {
                setSelectValue($('#node\\.fm_udp_type'), data.fm_udp_type);
                $('#node\\.fm_udp_salamander_password').val(data.fm_udp_salamander_password || '');
                setMultiSelectValue('#node\\.fm_udp_udphop_mode', data.fm_udp_udphop_mode || 'intervallocal');
                $('#node\\.fm_udp_udphop_interval').val(data.fm_udp_udphop_interval || '');
                $('#node\\.fm_udp_udphop_remote_ips').val(data.fm_udp_udphop_remote_ips || '');
                $('#node\\.fm_udp_udphop_remote_ports').val(data.fm_udp_udphop_remote_ports || '');
            }
            if (data.fm_tcp_type) {
                // A link whose FinalMask fits the rows fills them (the raw field stays empty)
                setSelectValue($('#node\\.fm_tcp_type'), data.fm_tcp_type);
                setSelectValue($('#node\\.fm_tcp_fragment_packets'), data.fm_tcp_fragment_packets || 'tlshello');
                fillTokenizeField('#node\\.fm_tcp_fragment_lengths', data.fm_tcp_fragment_lengths);
                fillTokenizeField('#node\\.fm_tcp_fragment_delays', data.fm_tcp_fragment_delays);
                $('#node\\.fm_tcp_fragment_max_split').val(data.fm_tcp_fragment_max_split || '');
            }

            // WireGuard
            $('#node\\.wg_secret_key').val(data.wg_secret_key);
            $('#node\\.wg_public_key').val(data.wg_public_key);
            $('#node\\.wg_preshared_key').val(data.wg_preshared_key);
            $('#node\\.wg_endpoint').val(data.wg_endpoint);
            fillTokenizeField('#node\\.wg_address', data.wg_address);
            fillTokenizeField('#node\\.wg_allowed_ips', data.wg_allowed_ips);
            $('#node\\.wg_keepalive').val(data.wg_keepalive || '0');
            $('#node\\.wg_mtu').val(data.wg_mtu || '1420');
            $('#node\\.wg_reserved').val(data.wg_reserved || '0,0,0');
            fillTokenizeField('#node\\.wg_remote_dns', data.wg_remote_dns);
            $('#node\\.wg_no_kernel_tun').prop('checked', data.wg_no_kernel_tun == '1');

            // Freedom / Blackhole / DNS / Loopback
            $('#node\\.freedom_redirect').val(data.freedom_redirect);
            var fpp = data.freedom_proxy_protocol;
            if (fpp === '1') {
                fpp = 'v1';
            } else if (fpp === '2') {
                fpp = 'v2';
            } else if (!fpp || fpp === '0') {
                fpp = 'off';
            }
            setSelectValue($('#node\\.freedom_proxy_protocol'), fpp);
            $('#node\\.freedom_final_rules').val(data.freedom_final_rules);
            setSelectValue($('#node\\.blackhole_response'), data.blackhole_response || 'none');
            setSelectValue($('#node\\.dns_rewrite_network'), data.dns_rewrite_network || 'keep');
            $('#node\\.dns_rewrite_address').val(data.dns_rewrite_address);
            $('#node\\.dns_rewrite_port').val(data.dns_rewrite_port);
            $('#node\\.dns_rules_json').val(data.dns_rules_json);
            $('#node\\.loopback_inbound_tag').val(data.loopback_inbound_tag || 'loopback-in');

            // Hysteria 2
            $('#node\\.hysteria_auth').val(data.hysteria_auth);
            $('#node\\.hysteria_udp_idle_timeout').val(data.hysteria_udp_idle_timeout || '60');

            // MASQUE
            $('#node\\.masque_host').val(data.masque_host);
            $('#node\\.masque_path').val(data.masque_path);
            fillTokenizeField('#node\\.masque_remote_dns', data.masque_remote_dns);
            // An imported link never carries WARP keys.
            setSelectValue($('#node\\.masque_mode'), 'custom');
            $('#node\\.masque_warp_private_key, #node\\.masque_warp_public_key').val('');
            clearTokenizeField('#node\\.masque_warp_address');

            $('#node\\.mux_enabled').prop('checked', data.mux_enabled == '1');

            $('#node\\.protocol').trigger('change');
            $('#node\\.network').trigger('change');
            $('#node\\.security').trigger('change');
            toggleNodeDialogFields();
        }

        $('#DialogNode').on('shown.bs.modal', function () {
            $('#node_import_notice').remove();
            toggleNodeDialogFields();
            injectWarpButton();
            if (pendingImport) {
                var data = pendingImport;
                pendingImport = null;
                fillNodeDialog(data);
                toggleNodeDialogFields();
                showImportNotice(data.import_warnings);
            }
        });

        // --- Advanced fields toggle (Kea-style eye icon) ---
        // Hides .expert_only rows (rarely needed knobs); persisted per browser.
        (function injectAdvancedToggle() {
            var expertIds = [
                'node.grpc_authority', 'node.grpc_user_agent', 'node.grpc_idle_timeout', 'node.grpc_health_check_timeout', 'node.grpc_permit_without_stream', 'node.grpc_initial_windows_size',
                'node.tls_verify_peer_cert_by_name', 'node.tls_use_system_ca', 'node.tls_pinned_peer_cert_sha256', 'node.tls_ech_config_list', 'node.tls_min_version', 'node.tls_max_version',
                'node.reality_mldsa65_verify', 'node.ws_heartbeat_period',
                'node.sockopt_domainStrategy', 'node.sockopt_dialer_proxy', 'node.sockopt_interface', 'node.sockopt_mark',
                'node.sockopt_tcp_congestion', 'node.sockopt_tcp_fast_open',
                'node.sockopt_tcp_keepalive_idle', 'node.sockopt_tcp_keepalive_interval', 'node.sockopt_tcp_user_timeout',
                'node.vmess_experiments',
                'node.wg_reserved', 'node.wg_mtu', 'node.wg_no_kernel_tun',
                'node.hysteria_udp_idle_timeout',
                'node.masque_remote_dns',
                'node.dns_rewrite_address', 'node.dns_rewrite_port', 'node.dns_rules_json',
                'node.freedom_proxy_protocol', 'node.freedom_final_rules',
                'node.blackhole_response',
                'node.loopback_inbound_tag',
                'node.http_headers',
                'node.custom_stream_json', 'node.finalmask'
            ];
            expertIds.forEach(function (id) {
                $('[id="' + id + '"]').addClass('expert_only');
            });
            // Every structured FinalMask field is advanced. The sections
            // themselves carry no field id, so mark the wrappers by their
            // header label and hide them with the same toggle.
            $('#frm_DialogNode :input[id^="node.fm_"]').addClass('expert_only');
            $('#frm_DialogNode .form-search-section').each(function () {
                if (/^FinalMask/i.test(sectionDetails($(this)).label)) {
                    $(this).addClass('expert_section');
                }
            });
            var saved = localStorage.getItem('osxray_show_advanced') === '1';
            $('#DialogNode').toggleClass('optional-hidden', !saved);
            window.osxrayNodeAdvanced = mountNativeAdvancedToggle('#frm_DialogNode', 'advanced fields', saved, function (show) {
                localStorage.setItem('osxray_show_advanced', show ? '1' : '0');
                $('#DialogNode').toggleClass('optional-hidden', !show);
            });
        })();

        // --- Help icon legend + collapsible sections in the node dialog ---
        // Help icons are classified by whether their field is required /
        // optional / advanced; the legend is shown above the form.
        (function setupDialogSections() {
            // Which fields must be filled in depends on what is selected:
            // a field is "mandatory" when the outbound cannot work without a
            // value the user has to type (no usable default), so an
            // address/port/UUID is mandatory for a proxy node while a Freedom
            // node needs none of them. Checkboxes and dropdowns with a
            // default are never mandatory.
            function nodeRequiredFields(st) {
                var proxies = ['vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http', 'hysteria', 'masque'];
                var req = ['node.name', 'node.protocol'];
                if (proxies.indexOf(st.proto) !== -1) {
                    req.push('node.address', 'node.port');
                }
                if (['vless', 'vmess', 'trojan', 'shadowsocks'].indexOf(st.proto) !== -1) {
                    req.push('node.user_uuid', 'node.network', 'node.security');
                }
                if (st.proto === 'wireguard') {
                    req.push('node.wg_secret_key', 'node.wg_public_key', 'node.wg_endpoint', 'node.wg_address');
                }
                if (st.proto === 'hysteria') {
                    req.push('node.hysteria_auth');
                }
                if (st.proto === 'masque' && st.masqueMode === 'warp') {
                    req.push('node.masque_warp_private_key', 'node.masque_warp_address');
                }
                if (st.proto === 'loopback') {
                    req.push('node.loopback_inbound_tag');
                }
                var streamish = ['vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http'].indexOf(st.proto) !== -1;
                if (streamish && st.sec === 'reality') {
                    req.push('node.reality_pubkey');
                }
                if (st.proto === 'vless' && st.net === 'xdrive') {
                    req.push('node.xdrive_remote_folder');
                    if (st.svc === 'google-drive') {
                        req.push('node.xdrive_google_client_id', 'node.xdrive_google_client_secret', 'node.xdrive_google_refresh_token');
                    } else if (st.svc === 's3') {
                        req.push('node.xdrive_s3_endpoint', 'node.xdrive_s3_bucket', 'node.xdrive_s3_access_key', 'node.xdrive_s3_secret_key');
                    } else if (st.svc === 'template') {
                        req.push('node.xdrive_template');
                    }
                }
                return req;
            }
            window.osxrayNodeRequiredFields = nodeRequiredFields;
            function classifyNodeHelpIcons() {
                var req = nodeRequiredFields({
                    proto: $('#node\\.protocol').val(),
                    net: $('#node\\.network').val(),
                    sec: $('#node\\.security').val(),
                    svc: $('#node\\.xdrive_service').val() || 'google-drive',
                    masqueMode: $('#node\\.masque_mode').val() || 'custom'
                });
                $('#frm_DialogNode .showhelp').each(function () {
                    var $a = $(this);
                    var id = ($a.attr('id') || '').replace(/^help_for_/, '');
                    var $row = $a.closest('tr, .form-group');
                    $a.removeClass('help-required help-optional help-advanced');
                    // .expert_only is added to the input, not to the row.
                    if ($row.find('.expert_only').length > 0) {
                        $a.addClass('help-advanced');
                    } else if (req.indexOf(id) !== -1) {
                        $a.addClass('help-required');
                    } else {
                        $a.addClass('help-optional');
                    }
                });
            }
            classifyNodeHelpIcons();
            $('#node\\.protocol, #node\\.network, #node\\.security, #node\\.xdrive_service').on('change', classifyNodeHelpIcons);
            $('#DialogNode').on('shown.bs.modal', classifyNodeHelpIcons);
            var legend = '<div class="xray-help-legend xray-help-legend--footer">'
                + '<span><i class="fa fa-info-circle icon-required"></i>mandatory</span>'
                + '<span><i class="fa fa-info-circle icon-optional"></i>optional</span>'
                + '<span><i class="fa fa-info-circle icon-advanced"></i>advanced</span>'
                + '</div>';
            $('#DialogNode .modal-footer').prepend(legend);

            $('#frm_DialogNode .form-search-section').each(function () {
                var $sec = $(this);
                var bits = sectionDetails($sec);
                if (!bits.$b.length) {
                    // The identity section (no header row) stays open.
                    return;
                }
                $sec.addClass('collapse-section');
                bits.$b.after('<span class="collapse-badge">error</span>');
            });

            function defaultOpen() {
                var proto = $('#node\\.protocol').val();
                var net = $('#node\\.network').val();
                var stream = ['vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http'].indexOf(proto) !== -1;
                var list = ['proto_' + proto];
                if (stream) {
                    list.push('proto_transport', 'net_' + net);
                }
                if (proto === 'vless' && net === 'xdrive') {
                    list.push('net_xdrive');
                }
                if (proto === 'hysteria' || proto === 'masque') {
                    list.push('proto_' + proto);
                }
                return list;
            }
            function applyNodeSectionState() {
                var open = defaultOpen();
                $('#frm_DialogNode .form-search-section').each(function () {
                    var $sec = $(this);
                    if (!$sec.hasClass('collapse-section')) {
                        return;
                    }
                    var label = sectionDetails($sec).label;
                    var stored = null;
                    try {
                        stored = localStorage.getItem('osxray_node_collapse_' + slugSection(label));
                    } catch (e) {}
                    if (stored === '1') {
                        setSectionCollapsed($sec, true);
                    } else if (stored === '0') {
                        setSectionCollapsed($sec, false);
                    } else if ($sec.find('[id="node.enabled"]').length > 0) {
                        // The identity section stays open by default.
                        setSectionCollapsed($sec, false);
                    } else {
                        var match = false;
                        open.forEach(function (c) {
                            if ($sec.hasClass(c)) {
                                match = true;
                            }
                        });
                        setSectionCollapsed($sec, !match);
                    }
                });
            }

            function applyNodeSectionsFromValidation(detail) {
                var secs = $('#frm_DialogNode .form-search-section');
                secs.removeClass('invalid');
                if (!detail || !detail.data || !detail.data.validations) {
                    return;
                }
                var keys = Object.keys(detail.data.validations);
                secs.each(function () {
                    var $sec = $(this);
                    var hit = keys.some(function (k) {
                        return $sec.find('[id="' + k + '"], [id^="' + k + '_"]').length > 0;
                    });
                    if (hit) {
                        setSectionCollapsed($sec, false);
                        $sec.addClass('invalid');
                    }
                });
            }

            // The OPNsense save call answers {result:'failed', validations:{...}}
            // but does not announce it as an event, so translate it here:
            // sections holding a failed field then expand themselves instead
            // of leaving the error inside a collapsed block.
            $(document).ajaxComplete(function (_e, xhr, settings) {
                var m = /\/api\/xrayclient\/settings\/(?:set|add)(Node|Rule)\b/.exec((settings && settings.url) || '');
                if (!m) {
                    return;
                }
                var data = xhr.responseJSON;
                if (!data) {
                    try { data = JSON.parse(xhr.responseText); } catch (err) { data = null; }
                }
                if (data && data.result === 'failed' && data.validations) {
                    $(document).trigger('validation-failed', [{
                        formid: m[1] === 'Node' ? 'frm_DialogNode' : 'frm_DialogRule',
                        data: data
                    }]);
                }
            });

            // Combo change must reapply defaults to sections without a stored state.
            $('#node\\.protocol, #node\\.network, #node\\.security, #node\\.encryption, #node\\.xdrive_service')
                .on('change', function () {
                    $('#frm_DialogNode .form-search-section').removeClass('invalid');
                    applyNodeSectionState();
                });

            $(document).on('validation-failed', function (_, detail) {
                if (!detail || detail.formid !== 'frm_DialogNode') {
                    return;
                }
                applyNodeSectionsFromValidation(detail);
            });

            // Initial application + expose for re-application.
            window.applyNodeSectionState = applyNodeSectionState;
            applyNodeSectionState();
        })();

        // --- Routing rule dialog: collapse "Additional conditions" by default ---
        (function setupRuleSections() {
            // Only fields without a usable default are mandatory: a rule needs
            // a description and a target; the switch, Seq and network have defaults.
            var requiredRule = { 'rule.description': true, 'rule.outbound_tag': true };
            $('#frm_DialogRule .showhelp').each(function () {
                var $a = $(this);
                var id = ($a.attr('id') || '').replace(/^help_for_/, '');
                var $row = $a.closest('tr, .form-group');
                if ($row.find('.expert_only').length > 0) {
                    $a.addClass('help-advanced');
                } else if (Object.prototype.hasOwnProperty.call(requiredRule, id)) {
                    $a.addClass('help-required');
                } else {
                    $a.addClass('help-optional');
                }
            });

            $('#frm_DialogRule .form-search-section').each(function () {
                var $sec = $(this);
                var bits = sectionDetails($sec);
                if (!bits.$b.length) { return; }
                $sec.addClass('collapse-section');
                bits.$b.after('<span class="collapse-badge">error</span>');
            });
            $('#frm_DialogRule .form-search-section').each(function () {
                var $sec = $(this);
                if (!$sec.hasClass('collapse-section')) { return; }
                var label = sectionDetails($sec).label;
                var stored = null;
                try { stored = localStorage.getItem('osxray_rule_collapse_' + slugSection(label)); } catch (e) {}
                if (stored !== null && stored !== undefined) {
                    setSectionCollapsed($sec, stored === '1');
                } else {
                    var open = (label === 'Rule' || label === 'Match traffic by');
                    setSectionCollapsed($sec, !open);
                }
            });
            $(document).on('validation-failed', function (_, detail) {
                if (!detail || detail.formid !== 'frm_DialogRule') { return; }
                var secs = $('#frm_DialogRule .form-search-section');
                secs.removeClass('invalid');
                if (!detail.data || !detail.data.validations) { return; }
                var keys = Object.keys(detail.data.validations);
                secs.each(function () {
                    var $sec = $(this);
                    var hit = keys.some(function (k) {
                        return $sec.find('[id="' + k + '"], [id^="' + k + '_"]').length > 0;
                    });
                    if (hit) { setSectionCollapsed($sec, false); $sec.addClass('invalid'); }
                });
            });
            $('#frm_DialogRule').on('change', '.collapse-section', function () {
                $('#frm_DialogRule .form-search-section').removeClass('invalid');
            });
        })();

        // --- Routing rule dialog: hide rarely used conditions by default ---
        (function injectRuleAdvancedToggle() {
            ['rule.inbound_tag', 'rule.source', 'rule.source_port', 'rule.user', 'rule.rule_tag', 'rule.sequence'].forEach(function (id) {
                $('[id="' + id + '"]').addClass('expert_only');
            });
            // The section header row has no input of its own; find it by text.
            $('#DialogRule tr').filter(function () {
                return $.trim($(this).find('th, h2, h3, h4, .header').first().text()) === 'Additional conditions (rarely needed)'
                    || $.trim($(this).text()) === 'Additional conditions (rarely needed)';
            }).addClass('expert_hdr');
            var saved = localStorage.getItem('osxray_show_advanced_rule') === '1';
            $('#DialogRule').toggleClass('optional-hidden', !saved);
            var ruleToggle = mountNativeAdvancedToggle('#frm_DialogRule', 'additional conditions', saved, function (show) {
                localStorage.setItem('osxray_show_advanced_rule', show ? '1' : '0');
                $('#DialogRule').toggleClass('optional-hidden', !show);
            });
            var legendRule = '<div class="xray-help-legend xray-help-legend--footer">'
                + '<span><i class="fa fa-info-circle icon-required"></i>mandatory</span>'
                + '<span><i class="fa fa-info-circle icon-optional"></i>optional</span>'
                + '<span><i class="fa fa-info-circle icon-advanced"></i>advanced</span>'
                + '</div>';
            $('#DialogRule .modal-footer').prepend(legendRule);
            // Editing a rule that already uses a hidden condition must not hide it.
            $('#DialogRule').on('shown.bs.modal', function () {
                var pref = localStorage.getItem('osxray_show_advanced_rule') === '1';
                var used = ['inbound_tag', 'source', 'source_port', 'user', 'rule_tag'].some(function (k) {
                    var v = $('[id="rule.' + k + '"]').val();
                    return Array.isArray(v) ? v.length > 0 : $.trim(v || '') !== '';
                });
                $('#DialogRule').toggleClass('optional-hidden', !(pref || used));
                ruleToggle.set(pref || used);
            });
        })();

        // --- Optional General Settings toggle ---
        // Same hide/show idea as the node dialog: fields that rarely change
        // (extra logging, advanced TUN/sniffing/observatory/DNS knobs) get the
        // expert_only class and disappear unless the user opts in. The choice
        // persists per browser, independently from the dialog's checkbox.
        (function injectGeneralAdvancedToggle() {
            var generalExpertIds = [
                'xrayclient.general.access_log', 'xrayclient.general.dns_log', 'xrayclient.general.mask_address',
                'xrayclient.general.tun_mtu', 'xrayclient.general.tun_ipv6_address', 'xrayclient.general.tun_auto_outbounds_interface',
                'xrayclient.general.sniffing_dest_override', 'xrayclient.general.sniffing_route_only', 'xrayclient.general.sniffing_domains_excluded',
                'xrayclient.general.stats_port',
                'xrayclient.general.telemetry_interval',
                'xrayclient.general.observatory_interval', 'xrayclient.general.observatory_sampling', 'xrayclient.general.observatory_timeout',
                'xrayclient.general.observatory_http_method', 'xrayclient.general.observatory_concurrency',
                'xrayclient.general.dns_disable_cache', 'xrayclient.general.dns_disable_fallback', 'xrayclient.general.dns_disable_fallback_if_match',
                'xrayclient.general.dns_enable_parallel_query', 'xrayclient.general.dns_use_system_hosts'
            ];
            generalExpertIds.forEach(function (id) {
                $('[id="' + id + '"]').addClass('expert_only');
            });
            // The DNS and observatory settings now live on their own tabs, each
            // with its own switch; all of them share one stored choice and
            // move together.
            var $tabs = $('#tab_general, #tab_dns, #tab_balancers, #tab_routing_policy');
            var saved = false;
            try { saved = localStorage.getItem('osxray_show_advanced_general') === '1'; } catch (e) {}
            $tabs.toggleClass('optional-hidden', !saved);
            var toggles = [];
            ['#frm_general', '#frm_general_dns', '#frm_general_obs', '#frm_general_route'].forEach(function (formSel) {
                toggles.push(mountNativeAdvancedToggle(formSel, 'advanced fields', saved, function (show) {
                    try { localStorage.setItem('osxray_show_advanced_general', show ? '1' : '0'); } catch (e) {}
                    $tabs.toggleClass('optional-hidden', !show);
                    toggles.forEach(function (t) { t.set(show); });
                }));
            });
        })();

        // --- WARP auto-config generation for WireGuard ---
        // Injects a "Generate WARP config" button into the WireGuard section
        // of the node dialog. Clicking it calls the backend WARP generator
        // (keypair + Cloudflare WARP registration) and fills all WireGuard fields.
        function injectWarpButton() {
            if ($('#btn_warp_generate').length > 0) return;
            // Find the WireGuard Settings section div by its header label text.
            var $b = $('#DialogNode .modal-body b:contains("WireGuard Settings")');
            if ($b.length === 0) return;
            var $section = $b.closest('.table-responsive.form-search-section');
            if ($section.length === 0) return;
            var $tbody = $section.find('> table > tbody');
            if ($tbody.length === 0) return;
            var $btnRow = $(
                '<tr style="text-align:left;">' +
                '<td colspan="3" style="padding-top:6px; padding-bottom:6px;">' +
                '<button id="btn_warp_generate" type="button" class="btn btn-xs btn-info" style="margin-top:6px;">' +
                '<i class="fa fa-cloud-download"></i> <b>Generate WARP config</b>' +
                '<i id="btn_warp_generate_spin" class="fa fa-spinner fa-pulse" style="display:none; margin-left:6px;"></i>' +
                '</button> ' +
                '<span id="warp_gen_status" class="text-muted" style="margin-left:8px; font-size:12px;"></span>' +
                '</td>' +
                '</tr>'
            );
            $tbody.prepend($btnRow);
            $btnRow.find('#btn_warp_generate').on('click', function () {
                generateWarpConfig();
            });
            // Make sure WireGuard fields are visible (in case protocol was just switched)
            toggleNodeDialogFields();
        }

        // Show a status line using text nodes only: messages come from the
        // WARP API / backend and must not be interpreted as HTML.
        function setWarpStatus($el, cssClass, text, boldText) {
            var $span = $('<span>').addClass(cssClass).text(text);
            if (boldText) {
                $span.append($('<b>').text(boldText)).append(document.createTextNode('. Save the node to apply.'));
            }
            $el.empty().append($span);
        }

        function generateWarpConfig() {
            var $btn = $('#btn_warp_generate');
            var $spin = $('#btn_warp_generate_spin');
            var $status = $('#warp_gen_status');
            $btn.prop('disabled', true);
            $spin.show();
            $status.text('Generating WireGuard keypair and registering with WARP…').show();
            $.ajax({
                url: '/api/xrayclient/service/warpGenerate',
                type: 'POST',
                timeout: 30000,
                success: function (data) {
                    $btn.prop('disabled', false);
                    $spin.hide();
                    if (!data || data.status !== 'ok') {
                        setWarpStatus($status, 'text-danger', 'Failed: ' + (data && data.message ? data.message : 'unknown error'));
                        return;
                    }
                    // Fill all WireGuard fields from the response
                    if (data.wg_secret_key) $('#node\\.wg_secret_key').val(data.wg_secret_key);
                    if (data.wg_public_key) $('#node\\.wg_public_key').val(data.wg_public_key);
                    if (data.wg_endpoint) $('#node\\.wg_endpoint').val(data.wg_endpoint);
                    if (data.wg_allowed_ips) setTokens('wg_allowed_ips', data.wg_allowed_ips.split(','));
                    if (data.wg_address) setTokens('wg_address', data.wg_address.split(','));
                    if (data.wg_remote_dns) setTokens('wg_remote_dns', data.wg_remote_dns.split(','));
                    if (data.wg_keepalive !== undefined) $('#node\\.wg_keepalive').val(data.wg_keepalive);
                    if (data.wg_mtu) $('#node\\.wg_mtu').val(data.wg_mtu);
                    if (data.wg_reserved) $('#node\\.wg_reserved').val(data.wg_reserved);
                    if (data.license) {
                        setWarpStatus($status, 'text-success', 'WARP config generated. License: ', String(data.license));
                    } else {
                        setWarpStatus($status, 'text-success', 'WARP config generated. Save the node to apply.');
                }
                if (data.warning) {
                    $status.append($('<br/>')).append($('<small class="text-warning">').text(data.warning));
                }
                // Select WireGuard protocol if not already
                if ($('#node\\.protocol').val() !== 'wireguard') {
                    $('#node\\.protocol').val('wireguard').selectpicker('refresh').trigger('change');
                }
            },
            error: function (xhr, status, err) {
                $btn.prop('disabled', false);
                $spin.hide();
                var msg = 'unknown error';
                if (status === 'timeout') {
                    msg = 'Request timed out (Cloudflare API unreachable). No node fields were changed.';
                } else if (xhr.responseText) {
                    try {
                        var j = JSON.parse(xhr.responseText);
                        msg = j.message || xhr.responseText.slice(0, 200);
                    } catch (e) {
                        msg = xhr.responseText.slice(0, 200);
                    }
                }
                setWarpStatus($status, 'text-danger', 'Failed: ' + msg);
            }
        });
        }

        // Helper: set tokenized select values (used by WARP fill)
        function setTokens(fieldId, values) {
            var $sel = $('#node\\.' + fieldId);
            if (!$sel.length) return;
            var merged = [];
            values.forEach(function (v) {
                v = v.trim();
                if (v && merged.indexOf(v) === -1) merged.push(v);
            });
            $sel.empty();
            merged.forEach(function (v) {
                $('<option/>').val(v).text(v).prop('selected', true).appendTo($sel);
            });
            if (typeof formatTokenizersUI === 'function') {
                formatTokenizersUI();
            }
            $sel.selectpicker('refresh');
            $sel.change();
        }

        // The node name accepts letters, digits, spaces and . _ - ( ) [ ] @ # / & ! + : ; , "
        // (the Mask in the model); flags, emoji and other scripts of a link's remark
        // are dropped, and the address stands in for a name that is left empty.
        function importName(remark, fallback) {
            var name = String(remark || '').replace(/[^A-Za-z0-9\s._\-()\[\]@#\/&!+:;,"]/g, '')
                .replace(/\s+/g, ' ').trim().substring(0, 192).trim();
            return name !== '' ? name : fallback;
        }

        function safeDecode(s) {
            try {
                return decodeURIComponent(s);
            } catch (e) {
                return s;
            }
        }

        // FinalMask of a link (fm=): a single TCP fragment that the rows can
        // show fills them; anything else (chains, other types, UDP, QUIC tuning)
        // goes into the raw FinalMask field, which wins over the rows.
        function importFinalMask(text) {
            var out = {fields: {}, raw: '', warning: ''};
            var obj;
            try {
                obj = JSON.parse(text);
            } catch (e) {
                out.warning = 'fm is not valid JSON and was not imported.';
                return out;
            }
            if (!obj || typeof obj !== 'object' || Array.isArray(obj) || !Object.keys(obj).length) {
                out.warning = 'fm is not a FinalMask object and was not imported.';
                return out;
            }
            var keys = Object.keys(obj);
            var item = obj.tcp && obj.tcp.length === 1 ? obj.tcp[0] : null;
            var st = item && item.settings ? item.settings : null;
            var item_ok = keys.length === 1 && keys[0] === 'tcp' && item && item.type === 'fragment' && st &&
                Object.keys(st).every(function (k) { return ['packets', 'lengths', 'delays', 'maxSplit'].indexOf(k) !== -1; }) &&
                (st.packets === 'tlshello' || st.packets === '1-3') &&
                [].concat(st.lengths || [], st.delays || []).every(function (v) { return /^\d{1,7}(-\d{1,7})?$/.test(String(v)); }) &&
                (st.maxSplit === undefined || /^\d{1,7}(-\d{1,7})?$/.test(String(st.maxSplit)));
            if (item_ok) {
                out.fields = {
                    fm_tcp_type: 'fragment',
                    fm_tcp_fragment_packets: st.packets,
                    fm_tcp_fragment_lengths: (st.lengths || []).map(String),
                    fm_tcp_fragment_delays: (st.delays || []).map(String),
                    fm_tcp_fragment_max_split: st.maxSplit === undefined ? '' : String(st.maxSplit)
                };
            } else {
                out.raw = JSON.stringify(obj, null, 2);
            }
            return out;
        }

        // Link parameters the node dialog cannot take, so that nothing is lost silently.
        function importWarnings(params, known) {
            var w = [];
            var fp = params.get('fp');
            if (fp && known.indexOf(fp) === -1) {
                w.push('Fingerprint "' + fp + '" is not one of the options here; the node keeps its default (chrome).');
            }
            var ht = params.get('headerType');
            if (ht && ht !== 'none') {
                w.push('Header type "' + ht + '" (obfuscation of the TCP stream) is not imported: the plugin has no such field.');
            }
            if (params.get('cs')) {
                w.push('Cipher suites (cs) are not imported: the plugin has no such field.');
            }
            return w;
        }

        function showImportNotice(list) {
            $('#node_import_notice').remove();
            if (!list || !list.length) {
                return;
            }
            var $n = $('<div id="node_import_notice" class="alert alert-warning" style="margin: 0 0 10px;"/>');
            list.forEach(function (t, i) {
                $n.append((i ? $('<br/>') : $()), document.createTextNode(t));
            });
            $('#DialogNode .modal-body').first().prepend($n);
        }

        // Fields every imported node starts from (the dialog keeps its defaults otherwise).
        function importBase(proto, name, host, port) {
            return {
                name: name, protocol: proto, address: host, port: port,
                user_uuid: '', flow: 'none', encryption: 'none', ss_method: 'x2022-blake3-aes-128-gcm',
                network: 'tcp', security: 'none', sni: '', allow_insecure: '0', fingerprint: 'chrome', alpn: '',
                reality_pubkey: '', reality_shortid: '', reality_spiderx: '/',
                transport_host: '', transport_path: '', grpc_service_name: '', xhttp_mode: 'auto'
            };
        }

        // hysteria2://auth@host:port?sni=..&insecure=1#name (also hy2://)
        function parseHysteria2Link(url, knownFp) {
            var params = url.searchParams;
            var auth = safeDecode(url.username) + (url.password ? ':' + safeDecode(url.password) : '');
            var data = importBase('hysteria', importName(url.hash ? safeDecode(url.hash.substring(1)) : '',
                url.hostname + ':' + (url.port || '443')), url.hostname, url.port || '443');
            data.security = 'tls';
            data.hysteria_auth = auth;
            data.sni = params.get('sni') || params.get('peer') || '';
            data.allow_insecure = (params.get('insecure') === '1' || params.get('allowInsecure') === '1') ? '1' : '0';
            data.alpn = params.get('alpn') || '';
            var w = [];
            var masks = [];
            // obfs=salamander is the Salamander FinalMask mask of the UDP direction
            if (params.get('obfs')) {
                if (String(params.get('obfs')).toLowerCase() === 'salamander') {
                    masks.push({type: 'salamander', settings: {password: params.get('obfs-password') || ''}});
                } else {
                    w.push('Obfuscation "' + params.get('obfs') + '" is not supported; Hysteria 2 knows only salamander.');
                }
            }
            // mport (port hopping): the remote ports of a UDP Hop mask, 30 s between hops like Hysteria
            if (params.get('mport')) {
                var ports = String(params.get('mport')).replace(/:/g, '-').replace(/\s+/g, '');
                if (/^\d{1,5}(-\d{1,5})?(,\d{1,5}(-\d{1,5})?)*$/.test(ports)) {
                    var isIp = /^\d{1,3}(\.\d{1,3}){3}$/.test(url.hostname);
                    var hop = {mode: 'intervalremote', interval: '30', remotePorts: ports};
                    if (isIp) {
                        hop.remoteIPs = [url.hostname];
                    } else {
                        w.push('Port hopping needs the server IP in the Remote IPs of the UDP Hop mask (the link has a host name).');
                    }
                    masks.push({type: 'udphop', settings: hop});
                } else {
                    w.push('Port hopping (mport) "' + params.get('mport') + '" could not be read and was not imported.');
                }
            }
            if (masks.length === 1 && masks[0].type === 'salamander') {
                data.fm_udp_type = 'salamander';
                data.fm_udp_salamander_password = masks[0].settings.password;
            } else if (masks.length === 1) {
                var h = masks[0].settings;
                data.fm_udp_type = 'udphop';
                data.fm_udp_udphop_mode = h.mode;
                data.fm_udp_udphop_interval = h.interval;
                data.fm_udp_udphop_remote_ips = (h.remoteIPs || []).join(',');
                data.fm_udp_udphop_remote_ports = h.remotePorts;
            } else if (masks.length > 1) {
                data.finalmask = JSON.stringify({udp: masks}, null, 2);
            }
            // pinSHA256 comes as hex with colons; the field takes 64 plain hex digits
            if (params.get('pinSHA256')) {
                var pin = String(params.get('pinSHA256')).replace(/[:\s]/g, '').toLowerCase();
                if (/^[0-9a-f]{64}$/.test(pin)) {
                    data.tls_pinned_peer_cert_sha256 = pin;
                } else {
                    w.push('pinSHA256 is not a SHA-256 digest and was not imported.');
                }
            }
            data.import_warnings = w;
            return data;
        }

        // vmess://base64(JSON) (v2rayN format)
        function parseVmessLink(raw) {
            var body = raw.replace(/^vmess:\/\//i, '');
            var hash = body.indexOf('#');
            var remark = hash !== -1 ? safeDecode(body.substring(hash + 1)) : '';
            if (hash !== -1) {
                body = body.substring(0, hash);
            }
            var j = JSON.parse(base64UrlDecode(body.trim()));
            var w = [];
            var net = String(j.net || 'tcp').toLowerCase();
            if (net === 'raw') net = 'tcp';
            if (net === 'splithttp') net = 'xhttp';
            if (['tcp', 'ws', 'grpc', 'xhttp', 'httpupgrade'].indexOf(net) === -1) {
                w.push('Transport "' + net + '" is not supported; the node was set to tcp.');
                net = 'tcp';
            }
            var data = importBase('vmess', importName(j.ps || j.name || remark, j.add + ':' + (j.port || '443')),
                String(j.add || ''), String(j.port || '443'));
            data.user_uuid = String(j.id || '');
            data.network = net;
            data.security = String(j.tls || '').toLowerCase() === 'tls' ? 'tls' : 'none';
            data.sni = j.sni || '';
            data.alpn = j.alpn || '';
            data.fingerprint = j.fp || 'chrome';
            data.allow_insecure = (j.insecure === '1' || j.insecure === 1 || j.allowInsecure === true) ? '1' : '0';
            data.transport_host = j.host || '';
            if (net === 'grpc') {
                data.grpc_service_name = j.path || '';
            } else {
                data.transport_path = j.path || '';
            }
            var scy = String(j.scy || 'auto');
            if (['auto', 'aes-128-gcm', 'chacha20-poly1305'].indexOf(scy) !== -1) {
                data.vmess_security = scy;
            } else {
                w.push('VMess security "' + scy + '" is not available; the node uses auto.');
                data.vmess_security = 'auto';
            }
            if (j.aid && String(j.aid) !== '0') {
                w.push('alterId ' + j.aid + ' is not imported (legacy VMess); Xray expects alterId 0.');
            }
            if (j.type && ['none', 'auto', '---'].indexOf(j.type) === -1) {
                w.push('Header type "' + j.type + '" is not imported.');
            }
            data.import_warnings = w;
            return data;
        }

        function base64UrlDecode(s) {
            s = s.replace(/-/g, '+').replace(/_/g, '/');
            while (s.length % 4 !== 0) s += '=';
            return decodeURIComponent(escape(atob(s)));
        }

        function parseSsLink(url, remarkFallback) {
            // SIP002: ss://base64(method:password)@host:port#remark
            // also: ss://method:password@host:port#remark (plain)
            var user = '';
            try {
                user = decodeURIComponent(url.username);
            } catch (e) {
                user = url.username;
            }
            var method = '';
            var password = '';
            try {
                var decoded = base64UrlDecode(user);
                var sep = decoded.indexOf(':');
                if (sep !== -1) {
                    method = decoded.substring(0, sep);
                    password = decoded.substring(sep + 1);
                }
            } catch (e) {
                // Fall through to plain interpretation below.
            }
            if (!method) {
                var sep = user.indexOf(':');
                if (sep !== -1) {
                    method = user.substring(0, sep);
                    password = user.substring(sep + 1);
                }
            }
            return {
                name: importName(url.hash ? safeDecode(url.hash.substring(1)) : '', remarkFallback),
                protocol: 'shadowsocks',
                address: url.hostname,
                port: url.port || '8388',
                user_uuid: decodeURIComponent(password),
                flow: 'none',
                encryption: 'none',
                ss_method: method || 'x2022-blake3-aes-128-gcm',
                network: 'tcp',
                security: 'none',
                sni: '',
                fingerprint: 'chrome',
                alpn: '',
                reality_pubkey: '',
                reality_shortid: '',
                reality_spiderx: '/',
                transport_host: '',
                transport_path: '',
                grpc_service_name: '',
                xhttp_mode: 'auto'
            };
        }

        $('#btn_parse_and_fill').on('click', function () {
            var raw = $('#import_link_input').val().trim();
            if (!raw) return;

            if (raw.startsWith('{') && raw.endsWith('}')) {
                try {
                    JSON.parse(raw);
                    $('#xrayclient\\.general\\.config_mode').val('raw').selectpicker('refresh');
                    $('#xrayclient\\.general\\.raw_json').val(raw);
                    toggleConfigModeUI();
                    toggleExpertTab(true);
                    $('#DialogImportLink').modal('hide');
                    showTab('#tab_expert');
                    return;
                } catch (e) {
                    $('#import_error_msg').text('Invalid JSON syntax: ' + e.message).show();
                    return;
                }
            }

            try {
                var knownFpAll = $('#node\\.fingerprint option').map(function () { return $(this).val(); }).get();
                if (/^vmess:\/\//i.test(raw)) {
                    pendingImport = parseVmessLink(raw);
                    if (pendingImport.fingerprint && knownFpAll.indexOf(pendingImport.fingerprint) === -1) {
                        pendingImport.import_warnings.push('Fingerprint "' + pendingImport.fingerprint + '" is not one of the options here; the node keeps its default (chrome).');
                    }
                    $('#DialogImportLink').one('hidden.bs.modal', function () {
                        $('#grid-nodes').parent().find('.command-add').trigger('click');
                    });
                    $('#DialogImportLink').modal('hide');
                    return;
                }
                var url = new URL(raw);
                var proto = url.protocol.replace(':', '').toLowerCase();

                if (proto === 'hysteria2' || proto === 'hy2') {
                    pendingImport = parseHysteria2Link(url, knownFpAll);
                    $('#DialogImportLink').one('hidden.bs.modal', function () {
                        $('#grid-nodes').parent().find('.command-add').trigger('click');
                    });
                    $('#DialogImportLink').modal('hide');
                    return;
                }

                if (proto === 'ss') {
                    var fallback = url.hostname + ':' + (url.port || '8388');
                    pendingImport = parseSsLink(url, fallback);
                    $('#DialogImportLink').one('hidden.bs.modal', function () {
                        $('#grid-nodes').parent().find('.command-add').trigger('click');
                    });
                    $('#DialogImportLink').modal('hide');
                    return;
                }

                if (proto !== 'vless' && proto !== 'trojan') {
                    throw new Error('Supported URI schemes: vless://, vmess://, trojan://, ss://, hysteria2:// (or paste a full JSON object).');
                }

                var params = url.searchParams;
                var remark = importName(url.hash ? safeDecode(url.hash.substring(1)) : '', url.hostname + ':' + (url.port || '443'));

                var netType = (params.get('type') || 'tcp').toLowerCase();
                if (netType === 'splithttp') netType = 'xhttp';
                if (netType === 'http') netType = 'httpupgrade';
                if (netType === 'raw') netType = 'tcp';

                var alpn = params.get('alpn') || '';
                if (!alpn) {
                    var allAlpn = params.getAll('alpn');
                    if (allAlpn.length > 1) {
                        alpn = allAlpn.join(',');
                    }
                }

                var extraJson = (function(){ try { return JSON.stringify(JSON.parse(params.get('extra') || ''), null, 2); } catch(e) { return params.get('extra') || ''; } })();
                pendingImport = {
                    name: remark,
                    protocol: proto,
                    address: url.hostname,
                    port: url.port || '443',
                    user_uuid: decodeURIComponent(url.username),
                    flow: params.get('flow') || 'none',
                    encryption: params.get('encryption') || 'none',
                    // 'extra' in a vless:// link is the XHTTP transport extra for
                    // type=splithttp/xhttp links (xPaddingBytes, scMaxEachPostBytes,
                    // headers, ...). Route it to xhttp_extra for those; everything
                    // else goes to the VLESS user extra field.
                    xhttp_extra: netType === 'xhttp' ? extraJson : '',
                    extra: netType === 'xhttp' ? '' : extraJson,
                    ss_method: 'x2022-blake3-aes-128-gcm',
                    network: netType,
                    security: (params.get('security') || 'none').toLowerCase(),
                    sni: params.get('sni') || params.get('serverName') || '',
                    allow_insecure: (params.get('allowInsecure') === '1' || params.get('insecure') === '1') ? '1' : '0',
                    fingerprint: params.get('fp') || 'chrome',
                    alpn: alpn,
                    reality_pubkey: params.get('pbk') || '',
                    reality_shortid: params.get('sid') || '',
                    reality_spiderx: params.get('spx') || '/',
                    transport_host: params.get('host') || '',
                    transport_path: params.get('path') || '',
                    grpc_service_name: params.get('serviceName') || '',
                    xhttp_mode: (params.get('mode') && netType === 'xhttp') ? params.get('mode') : 'auto',
                    // XDRIVE needs Mux.Cool; default it on for imported xdrive links
                    // so only the storage credentials are left to fill in.
                    mux_enabled: netType === 'xdrive' ? '1' : '0',
                    mux_concurrency: netType === 'xdrive' ? '128' : ''
                };

                var knownFp = $('#node\\.fingerprint option').map(function () { return $(this).val(); }).get();
                var warnings = importWarnings(params, knownFp);
                if (params.get('fm')) {
                    var fmImport = importFinalMask(params.get('fm'));
                    $.extend(pendingImport, fmImport.fields);
                    if (fmImport.raw) {
                        pendingImport.finalmask = fmImport.raw;
                    }
                    if (fmImport.warning) {
                        warnings.push(fmImport.warning);
                    }
                }
                pendingImport.import_warnings = warnings;

                $('#DialogImportLink').one('hidden.bs.modal', function () {
                    $('#grid-nodes').parent().find('.command-add').trigger('click');
                });

                $('#DialogImportLink').modal('hide');

            } catch (err) {
                $('#import_error_msg').text('Failed to parse link: ' + err.message).show();
            }
        });

        function refreshNodeTelemetry() {
            ajaxCall('/api/xrayclient/service/healthcheck', {}, function (data) {
                if (data && data.nodes) {
                    nodeLatencyCache = data.nodes;
                    $('#grid-nodes').bootgrid('reload');
                }
            });
            ajaxCall('/api/xrayclient/service/stats', {}, function (data) {
                if (data && data.stats) {
                    nodeTrafficCache = data.stats;
                    $('#grid-nodes').bootgrid('reload');
                }
            });
        }

        $('#btn_check_nodes').on('click', function () {
            var $btn = $(this);
            $btn.prop('disabled', true).find('i').addClass('fa-spin');
            refreshNodeTelemetry();
            setTimeout(function () {
                $btn.prop('disabled', false).find('i').removeClass('fa-spin');
            }, 2000);
        });

        // Put the nodes toolbar into the grid's own action bar so the tab has
        // one header row (our actions left, search and grid tools right). The
        // grid builds its bar asynchronously; if it never shows up, or has
        // another structure, the toolbar simply stays above the table.
        (function mergeNodesToolbar() {
            var tries = 0;
            var timer = setInterval(function () {
                tries++;
                var $bar = $('#tab_nodes .actionBar').first();
                var $tb = $('#nodes_toolbar');
                if ($bar.length && $tb.length) {
                    $tb.removeClass('col-md-12').prependTo($bar);
                    clearInterval(timer);
                } else if (tries >= 40) {
                    clearInterval(timer);
                }
            }, 250);
        })();

        // --- Automatic telemetry (background refresh) ---
        // Traffic is refreshed at the user-configured interval. Latency is a
        // TCP connect probe, so it is measured less often on a separate
        // hardcoded timer (5 minutes) — it does not need constant polling.
        var trafficTimer = null;
        var latencyTimer = null;
        var LATENCY_AUTO_INTERVAL = 300; // seconds (5 min), hardcoded

        // The automatic refresh intervals are shown as a tooltip of the manual
        // refresh button instead of a badge in the toolbar.
        function telemetryStatus(trafficActive, trafficInterval, latencyActive) {
            var parts = [];
            if (trafficActive) parts.push('traffic every ' + trafficInterval + ' s');
            if (latencyActive) parts.push('latency every ' + LATENCY_AUTO_INTERVAL + ' s');
            var tip = parts.length
                ? 'Measure now. Automatic refresh: ' + parts.join(', ') + '.'
                : 'Measure now. Automatic refresh is off (General Settings \u2192 Monitoring).';
            $('#btn_check_nodes').attr('title', tip);
            $('#telemetry_status').remove();
        }

        function refreshNodeLatency() {
            ajaxCall('/api/xrayclient/service/healthcheck', {}, function (data) {
                if (data && data.nodes) {
                    nodeLatencyCache = data.nodes;
                    $('#grid-nodes').bootgrid('reload');
                }
            });
        }

        function collectTrafficStats(data) {
            if (!data || !data.stats) {
                return false;
            }
            var now = Date.now();
            var prev = liveTrafficSample;
            nodeTrafficCache = data.stats;
            if (prev && (now - prev.time) > 400) {
                var dt = (now - prev.time) / 1000;
                $.each(data.stats, function (uuid, s) {
                    var p = prev.stats[uuid];
                    var dDown = p ? Math.max(0, parseInt(s.downlink || 0, 10) - parseInt(p.downlink || 0, 10)) : 0;
                    var dUp = p ? Math.max(0, parseInt(s.uplink || 0, 10) - parseInt(p.uplink || 0, 10)) : 0;
                    nodeTrafficRates[uuid] = {down: dDown / dt, up: dUp / dt};
                });
            }
            liveTrafficSample = {time: now, stats: data.stats};
            return true;
        }

        function updateLiveTrafficCells() {
            var rows = document.querySelectorAll('#grid-nodes .tabulator-row');
            for (var i = 0; i < rows.length; i++) {
                var uuidCell = rows[i].querySelector('.tabulator-cell[tabulator-field="uuid"]');
                var trafficCell = rows[i].querySelector('.tabulator-cell[tabulator-field="traffic"]');
                if (!uuidCell || !trafficCell) {
                    continue;
                }
                var uuid = uuidCell.textContent.trim();
                var st = nodeTrafficCache[uuid] || {downlink: 0, uplink: 0};
                trafficCell.innerHTML = renderTrafficCell(st, nodeTrafficRates[uuid]);
            }
        }

        function refreshNodeTraffic() {
            ajaxCall('/api/xrayclient/service/stats', {}, function (data) {
                if (!collectTrafficStats(data)) {
                    return;
                }
                $('#grid-nodes').bootgrid('reload');
                updateTotalTraffic(data.stats);
            });
        }

        // --- Live traffic: rates straight from cumulative counters, polled
        // every 2 s while the tab is visible. ---
        var liveTrafficTimer = null;
        var liveTrafficSample = null;
        var LIVE_TRAFFIC_INTERVAL = 5000;
        var liveTrafficBusy = false;
        var LIVE_TRAFFIC_KEY = 'osxray_live_traffic';
        $('#live_traffic_interval').text('\u00b7 ' + (LIVE_TRAFFIC_INTERVAL / 1000) + ' s');

        function startLiveTraffic() {
            if (liveTrafficTimer !== null) {
                return;
            }
            refreshLiveTraffic();
            liveTrafficTimer = setInterval(refreshLiveTraffic, LIVE_TRAFFIC_INTERVAL);
            $('#live_traffic_toggle').prop('checked', true);
            $('#live_traffic_dot').addClass('on');
        }

        function stopLiveTraffic(keepToggle) {
            if (liveTrafficTimer !== null) {
                clearInterval(liveTrafficTimer);
                liveTrafficTimer = null;
            }
            if (keepToggle !== true) {
                nodeTrafficRates = {};
                updateLiveTrafficCells();
                updateTotalTraffic(nodeTrafficCache);
                $('#live_traffic_toggle').prop('checked', false);
                $('#live_traffic_dot').removeClass('on');
            }
        }

        // Every sample runs `xray api statsquery` on the router, so poll only
        // while the Outbound Nodes tab is on screen, and never stack requests.
        function nodesTabVisible() {
            return $('#tab_nodes').hasClass('active');
        }

        function refreshLiveTraffic() {
            if (document.hidden || !nodesTabVisible()) {
                // A long gap would be averaged into a misleading rate.
                liveTrafficSample = null;
                return;
            }
            if (liveTrafficBusy) {
                return;
            }
            liveTrafficBusy = true;
            ajaxCall('/api/xrayclient/service/stats', {}, function (data) {
                liveTrafficBusy = false;
                if (!collectTrafficStats(data)) {
                    return;
                }
                updateLiveTrafficCells();
                updateTotalTraffic(data.stats);
            });
            // ajaxCall has no error callback: release the guard if no answer arrives.
            setTimeout(function () { liveTrafficBusy = false; }, LIVE_TRAFFIC_INTERVAL * 3);
        }

        $('#live_traffic_toggle').on('change', function () {
            var on = $(this).prop('checked');
            try {
                localStorage.setItem(LIVE_TRAFFIC_KEY, on ? '1' : '0');
            } catch (e) {}
            if (on) {
                startLiveTraffic();
            } else {
                stopLiveTraffic();
            }
        });

        document.addEventListener('visibilitychange', function () {
            var wanted = true;
            try {
                wanted = localStorage.getItem(LIVE_TRAFFIC_KEY) !== '0';
            } catch (e) {}
            if (document.visibilityState === 'visible') {
                if (wanted) {
                    startLiveTraffic();
                }
            } else {
                stopLiveTraffic(true);
            }
        });

        var liveWanted = true;
        try {
            liveWanted = localStorage.getItem(LIVE_TRAFFIC_KEY) !== '0';
        } catch (e) {}
        if (liveWanted) {
            startLiveTraffic();
        } else {
            $('#live_traffic_toggle').prop('checked', false);
        }

        function updateTotalTraffic(stats) {
            var totalDown = 0, totalUp = 0;
            $.each(stats, function (uuid, t) {
                totalDown += parseInt(t.downlink || 0, 10);
                totalUp += parseInt(t.uplink || 0, 10);
            });
            var rateDown = 0, rateUp = 0, hasRate = false;
            $.each(nodeTrafficRates, function (uuid, r) {
                rateDown += r.down;
                rateUp += r.up;
                hasRate = true;
            });
            var text;
            if (hasRate && liveTrafficTimer !== null) {
                text = 'Total: ↓ ' + formatRate(rateDown) + ' · ' + formatBytes(totalDown)
                    + ' / ↑ ' + formatRate(rateUp) + ' · ' + formatBytes(totalUp);
            } else {
                text = 'Total traffic: ↓ ' + formatBytes(totalDown) + ' / ↑ ' + formatBytes(totalUp);
            }
            $('#telemetry_total').text(text);
        }

        function startTelemetryAutoRefresh() {
            if (trafficTimer !== null) { clearInterval(trafficTimer); trafficTimer = null; }
            if (latencyTimer !== null) { clearInterval(latencyTimer); latencyTimer = null; }
            telemetryStatus(false, 0, false);

            var $cb = $('#xrayclient\\.general\\.auto_telemetry');
            var $int = $('#xrayclient\\.general\\.telemetry_interval');
            if (!$cb.length || !$cb.prop('checked')) return;

            var trafficInterval = parseInt($int.val(), 10) || 60;
            if (trafficInterval < 30) { trafficInterval = 30; }
            if (trafficInterval > 3600) { trafficInterval = 3600; }

            trafficTimer = setInterval(refreshNodeTraffic, trafficInterval * 1000);
            latencyTimer = setInterval(refreshNodeLatency, LATENCY_AUTO_INTERVAL * 1000);
            telemetryStatus(true, trafficInterval, true);
        }

        $(document).on('click', '#grid-rules .command-move-up, #grid-rules .command-move-down', function () {
            var $btn = $(this);
            var direction = $btn.hasClass('command-move-up') ? 'up' : 'down';
            var uuid = $btn.data('row-id');
            ajaxCall('/api/xrayclient/settings/moveRule/' + uuid + '/' + direction, {}, function () {
                $('#grid-rules').bootgrid('reload');
            });
        });

        // Raw JSON rows: catch syntax and shape errors in the browser
        // so the user gets a readable message instead of a configd template
        // error or an `xray run -test` failure on Apply.
        function jsonSectionError() {
            var checks = [
                ['#xrayclient\\.general\\.dns_json', 'Built-in DNS', 'object'],
                ['#xrayclient\\.general\\.balancers_json', 'Load Balancers', 'array'],
                ['#xrayclient\\.general\\.observatory_json', 'Observatory', 'object'],
                ['#xrayclient\\.general\\.dns_hosts_json', 'Static Hosts', 'object']
            ];
            for (var i = 0; i < checks.length; i++) {
                var $field = $(checks[i][0]);
                // A row hidden because it does not apply to the chosen
                // protocol/transport (inline display:none) is not saved
                // meaningfully; its leftover text must not block the save.
                var $row = $field.closest('tr, .form-group');
                if ($row.length && $row[0].style.display === 'none') {
                    continue;
                }
                var raw = $.trim($field.val() || '');
                if (raw === '') {
                    continue;
                }
                var parsed;
                try {
                    parsed = JSON.parse(raw);
                } catch (e) {
                    return checks[i][1] + ': invalid JSON — ' + e.message;
                }
                var isArray = Object.prototype.toString.call(parsed) === '[object Array]';
                if (checks[i][2] === 'array' && !isArray) {
                    return checks[i][1] + ': must be a JSON array, e.g. [ { ... } ].';
                }
                if (checks[i][2] === 'object' && (isArray || parsed === null || typeof parsed !== 'object')) {
                    return checks[i][1] + ': must be a JSON object, e.g. { ... }.';
                }
            }
            return '';
        }

        function showJsonSectionError(message, title) {
            if (typeof BootstrapDialog !== 'undefined') {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_WARNING,
                    title: title || 'Invalid JSON section',
                    message: $('<div/>').text(message)
                });
            } else {
                alert(message);
            }
        }

        // Raw JSON fields in the node dialog: the config template splices
        // them into config.json unvalidated, so catch syntax/shape errors
        // here before the dialog is serialized and saved.
        function nodeRawJsonError() {
            var checks = [
                ['#node\\.extra', 'Extra (VLESS)', 'object'],
                ['#node\\.xhttp_extra', 'XHTTP Extra', 'object'],
                ['#node\\.xdrive_extra', 'XDRIVE Extra', 'object'],
                ['#node\\.finalmask', 'Final Mask', 'object'],
                ['#node\\.fm_tcp_extra_json', 'FinalMask TCP Settings', 'object'],
                ['#node\\.fm_udp_extra_json', 'FinalMask UDP Settings', 'object'],
                ['#node\\.custom_stream_json', 'Custom Stream JSON', 'object'],
                ['#node\\.http_headers', 'HTTP Headers', 'object'],
                ['#node\\.freedom_final_rules', 'Final Rules', 'array'],
                ['#node\\.dns_rules_json', 'DNS Rules', 'array']
            ];
            for (var i = 0; i < checks.length; i++) {
                var $field = $(checks[i][0]);
                // A row hidden because it does not apply to the chosen
                // protocol/transport (inline display:none) is not saved
                // meaningfully; its leftover text must not block the save.
                var $row = $field.closest('tr, .form-group');
                if ($row.length && $row[0].style.display === 'none') {
                    continue;
                }
                var raw = $.trim($field.val() || '');
                if (raw === '') {
                    continue;
                }
                var parsed;
                try {
                    parsed = JSON.parse(raw);
                } catch (e) {
                    return { label: checks[i][1], message: 'invalid JSON — ' + e.message, selector: checks[i][0] };
                }
                var isArray = Object.prototype.toString.call(parsed) === '[object Array]';
                if (checks[i][2] === 'array' && !isArray) {
                    return { label: checks[i][1], message: 'must be a JSON array, e.g. [ { ... } ].', selector: checks[i][0] };
                }
                if (checks[i][2] === 'object' && (isArray || parsed === null || typeof parsed !== 'object')) {
                    return { label: checks[i][1], message: 'must be a JSON object, e.g. { ... }.', selector: checks[i][0] };
                }
            }
            return null;
        }

        // ---- MASQUE / Cloudflare WARP helpers ----
        // MASQUEWARP_BEGIN
        var WARP_MASQUE_SNI = 'consumer-masque.cloudflareclient.com';
        var WARP_MASQUE_ENDPOINTS = {
            warp: { v4: '162.159.198.2', v6: '2606:4700:103::2' },
            warp_plus: { v4: '162.159.199.2', v6: '2606:4700:104::2' },
            zero_trust: { v4: '162.159.197.2', v6: '2606:4700:102::2' }
        };

        // PEM text (or the base64 of PEM text) -> bare base64 body; bare
        // base64 is returned as it is.
        function warpPemToBase64(text) {
            var t = String(text || '').trim();
            if (t === '') {
                return '';
            }
            if (t.indexOf('-----BEGIN') === -1 && /^[A-Za-z0-9+\/=\s]+$/.test(t)) {
                try {
                    var decoded = (typeof atob === 'function') ? atob(t.replace(/\s+/g, '')) : '';
                    if (decoded.indexOf('-----BEGIN') !== -1) {
                        t = decoded;
                    }
                } catch (e) {
                    /* not base64 text: keep as is */
                }
            }
            return t.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
        }

        // Reads the config.json written by "usque register" and returns the
        // WARP MASQUE fields; throws an Error with a readable message.
        function warpImportUsque(text) {
            var cfg;
            try {
                cfg = JSON.parse(String(text || ''));
            } catch (e) {
                throw new Error('This is not valid JSON.');
            }
            if (cfg === null || typeof cfg !== 'object' || Array.isArray(cfg)) {
                throw new Error('Expected the JSON object of the usque config.');
            }
            var out = { privateKey: warpPemToBase64(cfg.private_key), publicKey: warpPemToBase64(cfg.endpoint_pub_key),
                        addresses: [], address: '' };
            if (out.privateKey === '') {
                throw new Error('The config has no private_key.');
            }
            if (typeof cfg.ipv4 === 'string' && cfg.ipv4 !== '') {
                out.addresses.push(cfg.ipv4.indexOf('/') === -1 ? cfg.ipv4 + '/32' : cfg.ipv4);
            }
            if (typeof cfg.ipv6 === 'string' && cfg.ipv6 !== '') {
                out.addresses.push(cfg.ipv6.indexOf('/') === -1 ? cfg.ipv6 + '/128' : cfg.ipv6);
            }
            if (typeof cfg.endpoint_v4 === 'string' && cfg.endpoint_v4 !== '') {
                out.address = cfg.endpoint_v4.replace(/:\d+$/, '');
            }
            return out;
        }
        // MASQUEWARP_END

        // Fills the node dialog from the answer of the WARP registration.
        function warpApplyGenerated(data) {
            $('#node\\.masque_warp_private_key').val(data.private_key || '');
            $('#node\\.masque_warp_public_key').val(data.edge_public_key || '');
            if (data.addresses && data.addresses.length) {
                setTokens('masque_warp_address', data.addresses);
            }
            if (data.endpoint) {
                $('#node\\.address').val(data.endpoint);
                $('#node\\.port').val(String(data.port || 443));
            }
            if ($.trim($('#node\\.sni').val() || '') === '') {
                $('#node\\.sni').val(data.sni || WARP_MASQUE_SNI);
            }
            var alpn = $('#node\\.alpn').val() || [];
            if (alpn.length === 0 && $('#node\\.alpn').length) {
                $('#node\\.alpn').val(['h2']);
                if ($.fn.selectpicker) {
                    $('#node\\.alpn').selectpicker('refresh');
                }
                $('#node\\.alpn').trigger('change');
            }
        }

        (function installMasqueWarpTools() {
            var $row = $('#node\\.masque_warp_address').closest('tr, .form-group');
            if ($row.length === 0 || $('#masque_warp_tools').length > 0) {
                return;
            }
            var isTr = $row.is('tr');
            var $tools = $(isTr ? '<tr id="masque_warp_tools" class="masque_warp"><td colspan="3"></td></tr>'
                                : '<div id="masque_warp_tools" class="form-group masque_warp"></div>');
            var $cell = isTr ? $tools.find('td') : $tools;
            var $gen = $('<button id="btn_masque_warp_generate" type="button" class="btn btn-xs btn-primary" style="margin-right: 8px;">' +
                '<i class="fa fa-cloud-download"></i> <b>Generate WARP config</b></button>');
            var $acc = $('<select id="masque_warp_account" class="form-control" style="width: auto; display: inline-block;"></select>')
                .append('<option value="">Endpoint for account type…</option>')
                .append('<option value="warp">WARP</option>')
                .append('<option value="warp_plus">WARP+</option>')
                .append('<option value="zero_trust">Zero Trust</option>');
            var $fetch = $('<button id="btn_masque_warp_edge" type="button" class="btn btn-xs btn-info" style="margin-left: 6px;">' +
                '<i class="fa fa-key"></i> <b>Fetch edge key</b></button>');
            var $status = $('<span id="masque_warp_status" class="text-muted" style="margin-left: 8px; font-size: 12px;"></span>');
            var $imp = $('<textarea id="masque_warp_usque" class="form-control" rows="3" style="margin-top: 8px;" ' +
                'placeholder="Paste the config.json written by usque register here"></textarea>');
            var $impBtn = $('<button id="btn_masque_warp_import" type="button" class="btn btn-xs btn-default" style="margin-top: 6px;">' +
                '<i class="fa fa-download"></i> Import from usque config</button>');
            $cell.append($gen).append($acc).append($fetch).append($status).append($imp).append($impBtn);
            $row.after($tools);

            function say(cls, text) {
                $status.removeClass('text-muted text-danger text-success').addClass(cls).text(text);
            }

            $gen.on('click', function () {
                $gen.prop('disabled', true);
                say('text-muted', 'Registering a WARP device with Cloudflare…');
                $.ajax({
                    url: '/api/xrayclient/service/warpMasqueGenerate',
                    type: 'POST',
                    timeout: 60000,
                    success: function (data) {
                        $gen.prop('disabled', false);
                        if (!data || data.status !== 'ok') {
                            say('text-danger', 'Failed: ' + (data && data.message ? data.message : 'unknown error') + ' No node fields were changed.');
                            return;
                        }
                        warpApplyGenerated(data);
                        say('text-success', 'WARP device registered and the fields are filled in. Save the node to apply.');
                    },
                    error: function (xhr, status) {
                        $gen.prop('disabled', false);
                        say('text-danger', (status === 'timeout' ? 'Request timed out (Cloudflare API unreachable).' : 'Request failed.') + ' No node fields were changed.');
                    }
                });
            });

            // The choice only fills the endpoint; it is not saved with the node,
            // so every time the dialog opens the list starts empty again.
            $('#DialogNode').on('show.bs.modal', function () {
                $acc.val('');
                if ($.fn.selectpicker) {
                    $acc.selectpicker('refresh');
                }
            });

            $acc.on('change', function () {
                var ep = WARP_MASQUE_ENDPOINTS[this.value];
                if (!ep) {
                    return;
                }
                $('#node\\.address').val(ep.v4);
                $('#node\\.port').val('443');
                if ($.trim($('#node\\.sni').val() || '') === '') {
                    $('#node\\.sni').val(WARP_MASQUE_SNI);
                }
                var alpn = $('#node\\.alpn').val() || [];
                if (alpn.length === 0 && $('#node\\.alpn').length) {
                    $('#node\\.alpn').val(['h2']);
                    if ($.fn.selectpicker) {
                        $('#node\\.alpn').selectpicker('refresh');
                    }
                    $('#node\\.alpn').trigger('change');
                }
                say('text-muted', 'Endpoint set to ' + ep.v4 + ':443 (IPv6 ' + ep.v6 + '). The edge key belongs to this IP: fetch it again after any change.');
            });

            $fetch.on('click', function () {
                var addr = $.trim($('#node\\.address').val() || '');
                if (addr === '') {
                    say('text-danger', 'Set the endpoint address first (or pick an account type).');
                    return;
                }
                $fetch.prop('disabled', true);
                say('text-muted', 'Reading the edge certificate…');
                $.ajax({
                    url: '/api/xrayclient/service/warpEdgeKey',
                    type: 'POST',
                    timeout: 30000,
                    data: { address: addr, port: $.trim($('#node\\.port').val() || '443'),
                            sni: $.trim($('#node\\.sni').val() || '') || WARP_MASQUE_SNI },
                    success: function (data) {
                        $fetch.prop('disabled', false);
                        if (data && data.status === 'ok' && data.public_key) {
                            $('#node\\.masque_warp_public_key').val(data.public_key);
                            say('text-success', 'Edge public key filled in. Save the node to apply.');
                        } else {
                            say('text-danger', 'Failed: ' + (data && data.message ? data.message : 'unknown error'));
                        }
                    },
                    error: function (xhr, status) {
                        $fetch.prop('disabled', false);
                        say('text-danger', status === 'timeout' ? 'Request timed out.' : 'Request failed.');
                    }
                });
            });

            $impBtn.on('click', function () {
                var res;
                try {
                    res = warpImportUsque($imp.val());
                } catch (e) {
                    say('text-danger', e.message);
                    return;
                }
                $('#node\\.masque_warp_private_key').val(res.privateKey);
                if (res.publicKey) {
                    $('#node\\.masque_warp_public_key').val(res.publicKey);
                }
                if (res.addresses.length) {
                    setTokens('masque_warp_address', res.addresses);
                }
                if (res.address && $.trim($('#node\\.address').val() || '') === '') {
                    $('#node\\.address').val(res.address);
                    $('#node\\.port').val('443');
                }
                if ($.trim($('#node\\.sni').val() || '') === '') {
                    $('#node\\.sni').val(WARP_MASQUE_SNI);
                }
                $imp.val('');
                say('text-success', 'Imported the device key and addresses. Save the node to apply.');
            });
        })();

        // ---- WARP endpoint search (WireGuard and MASQUE nodes) ----
        // WARPPROBE_BEGIN
        function warpAgeText(ts, now) {
            var secs = Math.max(0, (now || Math.floor(Date.now() / 1000)) - (ts || 0));
            if (!ts) {
                return '';
            }
            if (secs < 90) {
                return 'just now';
            }
            if (secs < 5400) {
                return Math.round(secs / 60) + ' min ago';
            }
            if (secs < 129600) {
                return Math.round(secs / 3600) + ' h ago';
            }
            return Math.round(secs / 86400) + ' d ago';
        }

        // Rows of the result table: what the current search found plus the
        // endpoints verified earlier (kept on the router), best latency first.
        function warpProbeRows(state, mode) {
            var rows = {};
            var cached = (state && state.cached && state.cached[mode]) || [];
            cached.forEach(function (r) {
                rows[r.host + ':' + r.port] = $.extend({ cached: true }, r);
            });
            if (state && state.mode === mode) {
                (state.results || []).forEach(function (r) {
                    rows[r.host + ':' + r.port] = $.extend({ cached: false }, r);
                });
            }
            return Object.keys(rows).map(function (k) { return rows[k]; }).sort(function (a, b) {
                var rank = function (r) { return r.status === 'verified' ? 0 : (r.status === 'unstable' ? 1 : 2); };
                return rank(a) - rank(b) || (a.ms || 1e9) - (b.ms || 1e9);
            });
        }

        // Flag emoji of a two letter country code ('' when there is none).
        function warpFlag(cc) {
            if (!/^[A-Za-z]{2}$/.test(cc || '')) {
                return '';
            }
            return String.fromCodePoint.apply(null, cc.toUpperCase().split('').map(function (c) {
                return 0x1F1E6 + c.charCodeAt(0) - 65;
            }));
        }

        // Tooltip of the flag: city, country name and the data center code.
        function warpPlaceTitle(r) {
            var name = r.cc || '';
            try {
                name = new Intl.DisplayNames(['en'], { type: 'region' }).of(r.cc) || name;
            } catch (e) { /* older browser: the code stays */ }
            return [r.city, name].filter(function (v) { return v; }).join(', ') +
                (r.colo ? ' (Cloudflare data center ' + r.colo + ')' : '');
        }

        // One line about the external lists a search used (empty when none).
        function warpSourcesText(sources) {
            if (!sources || !sources.length) {
                return '';
            }
            return 'External lists: ' + sources.map(function (r) {
                if (r.status === 'error') {
                    return 'could not load (' + (r.message || 'error') + ')';
                }
                var t = r.accepted + ' of ' + r.count + ' endpoints used';
                if (r.skipped) {
                    t += ', ' + r.skipped + ' outside Cloudflare ranges skipped';
                }
                if (r.status === 'stale') {
                    t += ', old copy (' + (r.message || 'refresh failed') + ')';
                }
                return t;
            }).join('; ') + '.';
        }
        // WARPPROBE_END

        (function installWarpProbePanels() {
            function val(id) {
                return $.trim($('#node\\.' + id).val() || '');
            }
            function listVal(id) {
                var v = $('#node\\.' + id).val();
                return $.isArray(v) ? v : String(v || '').split(',').filter(function (x) { return $.trim(x) !== ''; });
            }

            function credentials(kind) {
                if (kind === 'wg') {
                    return { wg_secret_key: val('wg_secret_key'), wg_public_key: val('wg_public_key'),
                             wg_preshared_key: val('wg_preshared_key'), wg_address: listVal('wg_address').join(','),
                             wg_allowed_ips: listVal('wg_allowed_ips').join(','), wg_mtu: val('wg_mtu'),
                             wg_reserved: val('wg_reserved') };
                }
                return { masque_warp_private_key: val('masque_warp_private_key'),
                         masque_warp_public_key: val('masque_warp_public_key'),
                         masque_warp_address: listVal('masque_warp_address').join(','), sni: val('sni'),
                         fingerprint: val('fingerprint'), tls_pinned_peer_cert_sha256: val('tls_pinned_peer_cert_sha256'),
                         tls_verify_peer_cert_by_name: val('tls_verify_peer_cert_by_name') };
            }

            // FinalMask rows of the node dialog as they stand (the server decides what is used).
            function fmValues() {
                var out = {};
                $('#DialogNode [id^="node.fm_"]').each(function () {
                    var v = $(this).val();
                    out[this.id.replace('node.', '')] = $.isArray(v) ? v.join(',') : String(v === null || v === undefined ? '' : v);
                });
                var raw = $('#node\\.finalmask');
                if (raw.length) {
                    out.finalmask = $.trim(raw.val() || '');
                }
                return out;
            }

            function missing(kind, cred) {
                var need = kind === 'wg' ? ['wg_secret_key', 'wg_public_key', 'wg_address']
                                          : ['masque_warp_private_key', 'masque_warp_address'];
                var names = { wg_secret_key: 'Client Private Key', wg_public_key: 'Peer Public Key', wg_address: 'Addresses',
                              masque_warp_private_key: 'WARP Private Key', masque_warp_address: 'WARP Device Addresses' };
                return need.filter(function (k) { return cred[k] === ''; }).map(function (k) { return names[k]; });
            }

            function build(kind, $anchorRow) {
                if ($anchorRow.length === 0 || $('#warp_probe_' + kind).length > 0) {
                    return;
                }
                var isTr = $anchorRow.is('tr');
                var $wrap = $('<div class="warp-probe" id="warp_probe_' + kind + '" style="margin-top: 8px;"></div>');
                var $row = $(isTr ? '<tr class="' + ($anchorRow.attr('class') || '') + '"><td colspan="3"></td></tr>'
                                  : '<div class="form-group ' + ($anchorRow.attr('class') || '') + '"></div>');
                (isTr ? $row.find('td') : $row).append($wrap);
                var modeHtml = kind === 'wg' ? '' :
                    '<label class="radio-inline"><input type="radio" name="warp_probe_mode" value="masque_h2" checked> HTTP/2 (TCP)</label> ' +
                    '<label class="radio-inline"><input type="radio" name="warp_probe_mode" value="masque_h3"> HTTP/3 (UDP)</label>';
                $wrap.html(
                    '<button type="button" class="btn btn-xs btn-primary wp-start"><i class="fa fa-search"></i> <b>Find working endpoint</b></button> ' +
                    '<a href="#" class="wp-opts-toggle" style="margin-left: 8px; font-size: 12px;">Options</a>' +
                    '<a href="#" class="wp-show" style="margin-left: 8px; font-size: 12px; display:none;">Results</a>' +
                    '<span class="wp-status text-muted" style="margin-left: 8px; font-size: 12px;"></span>' +
                    '<div class="wp-opts" style="display:none; margin-top: 6px;">' + modeHtml +
                    ' <label class="checkbox-inline"><input type="checkbox" class="wp-zt"> Zero Trust ranges</label>' +
                    ' <label class="checkbox-inline"><input type="checkbox" class="wp-ignore"> Retry endpoints that failed recently</label>' +
                    ' <label class="checkbox-inline" title="' + (kind === 'wg' ? 'Endpoints from the external lists below (one URL per line)' :
                        'No MASQUE list is published: the addresses of the external lists below are tried on port 443') + '"><input type="checkbox" class="wp-src"> Use external lists</label>' +
                    ' <label class="checkbox-inline" title="Normally only Cloudflare addresses are tested: a list could point the handshake at any host"><input type="checkbox" class="wp-any"> Also test addresses outside Cloudflare ranges</label>' +
                    (kind === 'wg' ? '' : ' <label class="checkbox-inline" title="Send the probe the way this node would: the FinalMask rows of the dialog are applied. Needed where the connection is filtered"><input type="checkbox" class="wp-fm" checked> Apply this node\'s FinalMask</label>') +
                    (kind === 'wg' ? '' : ' <label class="checkbox-inline" title="Experimental: other WARP ranges (162.159.192.x, 162.159.195.x and the WireGuard ranges) with the MASQUE ports"><input type="checkbox" class="wp-wide"> Also try other WARP ranges</label>') +
                    '<div class="wp-src-box" style="display:none; margin-top: 6px;">' +
                    '<div class="text-muted" style="font-size: 12px; margin-bottom: 2px;">External endpoint lists, one https:// URL per line. Saved with the plugin settings, shared by WireGuard and MASQUE searches.</div>' +
                    '<textarea class="form-control wp-src-urls" rows="3" spellcheck="false" style="max-width: none; font-family: monospace; font-size: 12px;" placeholder="https://example.com/warp-endpoints.json"></textarea>' +
                    '<div class="wp-src-msg" style="font-size: 12px; margin-top: 2px;"></div>' +
                    '<div class="text-muted" style="font-size: 12px; margin-top: 2px;">Accepted: JSON [{"ip": "8.6.112.0", "ports": [500, 939]}], JSON with ip:port strings or an ip-to-ports object, or text with ip:port lines. The router fetches the lists when a search starts and caches them for a day. Every entry is still tested end to end, and only Cloudflare addresses are used unless the option above allows others. Empty = built-in ranges only.</div></div>' +
                    '<div style="margin-top: 4px;">Stop after <input type="number" class="wp-want form-control" style="width: 5em; display: inline-block;" value="5" min="1" max="20"> verified, at most ' +
                    '<input type="number" class="wp-max form-control" style="width: 6em; display: inline-block;" value="80" min="1" max="300"> attempts</div>' +
                    '<div class="text-muted" style="font-size: 12px; margin-top: 4px;">Each candidate is tested with this node\'s keys through a temporary Xray on the router; FinalMask is applied when the option is ticked.</div></div>' +
                    '</div>');
                $anchorRow.after($row);
                // The progress and the results live in their own dialog above the node dialog.
                var dlgId = 'DialogWarpProbe_' + kind;
                $('#' + dlgId).remove();
                var $dlg = $('<div class="modal fade" id="' + dlgId + '" tabindex="-1" role="dialog"><div class="modal-dialog modal-lg"><div class="modal-content">' +
                    '<div class="modal-header"><button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>' +
                    '<h4 class="modal-title">Find working endpoint</h4></div>' +
                    '<div class="modal-body">' +
                    '<div class="wp-m-status text-muted"></div>' +
                    '<div class="progress" style="margin: 10px 0;"><div class="progress-bar wp-bar" style="width: 0%;"></div></div>' +
                    '<div class="wp-m-src text-muted" style="font-size: 12px; margin-bottom: 8px;"></div>' +
                    '<table class="table table-condensed wp-table" style="display:none;"><thead><tr>' +
                    '<th>Endpoint</th><th>Latency</th><th>Speed</th><th>Checks</th><th>Verified</th><th></th></tr></thead><tbody></tbody></table>' +
                    '<div class="wp-empty text-muted" style="display:none;">Nothing has answered yet.</div></div>' +
                    '<div class="modal-footer"><button type="button" class="btn btn-default wp-recheck-all" style="display:none;"><i class="fa fa-refresh"></i> Re-check all</button> ' +
                    '<button type="button" class="btn btn-default wp-cancel" style="display:none;">Cancel search</button> ' +
                    '<button type="button" class="btn btn-primary" data-dismiss="modal">Close</button></div>' +
                    '</div></div></div>').appendTo('body');
                var $status = $wrap.find('.wp-status');
                function openDialog() {
                    if ($.fn.modal) {
                        $dlg.modal('show');
                    } else {
                        $dlg.show();
                    }
                }
                function closeDialog() {
                    if ($.fn.modal) {
                        $dlg.modal('hide');
                    } else {
                        $dlg.hide();
                    }
                }
                // Stack above the node dialog; Bootstrap 3 removes modal-open from
                // the body when any dialog closes, so put it back for the node dialog.
                $dlg.on('shown.bs.modal', function () {
                    $dlg.css('z-index', 1070);
                    $('.modal-backdrop').last().css('z-index', 1065);
                });
                $dlg.on('hidden.bs.modal', function () {
                    if ($('#DialogNode').hasClass('in')) {
                        $('body').addClass('modal-open');
                        var node = $('#DialogNode').data('bs.modal');
                        if (node && node.enforceFocus) {
                            node.enforceFocus();
                        }
                    }
                });
                var polling = null;
                var running = false;

                function mode() {
                    return kind === 'wg' ? 'wg' : $wrap.find('input[name=warp_probe_mode]:checked').val();
                }
                function say(cls, text) {
                    $status.removeClass('text-muted text-danger text-success').addClass(cls).text(text);
                    $dlg.find('.wp-m-status').removeClass('text-muted text-danger text-success').addClass(cls).text(text);
                }
                function progress(st) {
                    var max = st && st.max_attempts ? st.max_attempts : 0;
                    var pct = max ? Math.min(100, Math.round(100 * (st.attempts || 0) / max)) : 0;
                    var done = st && st.status && st.status !== 'running';
                    $dlg.find('.wp-bar').css('width', (done ? (st.status === 'done' && st.verified >= (st.want || 1) ? 100 : pct) : pct) + '%')
                        .toggleClass('active progress-bar-striped', !done)
                        .toggleClass('progress-bar-success', !!done && (st.verified || 0) > 0)
                        .toggleClass('progress-bar-danger', !!done && !(st.verified || 0));
                    $dlg.find('.wp-m-src').text(warpSourcesText(st && st.sources));
                }

                function render(state) {
                    var rows = warpProbeRows(state, mode());
                    var $tb = $dlg.find('.wp-table tbody').empty();
                    rows.forEach(function (r) {
                        var label = r.status === 'verified' ? '<span class="label label-success">verified</span>'
                                  : (r.status === 'unstable' ? '<span class="label label-warning">unstable</span>'
                                  : '<span class="label label-danger">failed</span>');
                        var $ep = $('<td/>');
                        if (r.cc || r.colo) {
                            $ep.append($('<span/>').css({ 'margin-right': '6px', cursor: 'help' })
                                .attr('title', warpPlaceTitle(r)).text(warpFlag(r.cc) || r.colo));
                        }
                        $ep.append(document.createTextNode(r.host + ':' + r.port + ' ')).append($(label));
                        var $tr = $('<tr/>').append($ep)
                            .append($('<td/>').text(r.ms ? r.ms + ' ms' : '-'))
                            .append($('<td/>').text(r.kbps ? (r.kbps >= 1000 ? (r.kbps / 1000).toFixed(1) + ' Mbit/s' : r.kbps + ' kbit/s') : '-'))
                            .append($('<td/>').text(r.checks || '-'))
                            .append($('<td/>').text(warpAgeText(r.ts)));
                        var $use = $('<button type="button" class="btn btn-xs btn-default" style="margin-right: 4px;">Use</button>')
                            .prop('disabled', r.status === 'failed').on('click', function () { use(r); });
                        var $re = $('<button type="button" class="btn btn-xs btn-default">Re-check</button>')
                            .on('click', function () { start([{ host: r.host, port: r.port }]); });
                        var $acts = $('<td/>').append($use).append($re);
                        if (r.log && r.log.length) {
                            var $logRow = $('<tr class="wp-log" style="display:none;"><td colspan="6"><pre style="margin: 0; font-size: 11px; white-space: pre-wrap;"></pre></td></tr>');
                            $logRow.find('pre').text(r.log.join('\n'));
                            $acts.append($('<button type="button" class="btn btn-xs btn-default" style="margin-left: 4px;">Log</button>')
                                .on('click', function () { $logRow.toggle(); }));
                            $tr.append($acts).data('row', r);
                            $tb.append($tr).append($logRow);
                            return;
                        }
                        $tr.append($acts).data('row', r);
                        $tb.append($tr);
                    });
                    $dlg.find('.wp-table').toggle(rows.length > 0);
                    $dlg.find('.wp-recheck-all').toggle(rows.length > 0 && !running);
                    $dlg.find('.wp-empty').toggle(rows.length === 0 && !!(state && state.status && state.status !== 'running'));
                    $wrap.find('.wp-show').toggle(rows.length > 0);
                    $wrap.data('rows', rows);
                }

                function use(r) {
                    if (kind === 'wg') {
                        $('#node\\.wg_endpoint').val(r.host + ':' + r.port);
                    } else {
                        $('#node\\.address').val(r.host);
                        $('#node\\.port').val(String(r.port));
                        var $alpn = $('#node\\.alpn');
                        if ($alpn.length) {
                            $alpn.val([mode() === 'masque_h2' ? 'h2' : 'h3']);
                            if ($.fn.selectpicker) {
                                $alpn.selectpicker('refresh');
                            }
                            $alpn.trigger('change');
                        }
                        if (r.edge_key) {
                            $('#node\\.masque_warp_public_key').val(r.edge_key);
                        }
                    }
                    closeDialog();
                    say('text-success', 'Endpoint ' + r.host + ':' + r.port + ' filled in. Save the node to apply.');
                }

                function poll() {
                    $.ajax({ url: '/api/xrayclient/service/warpProbeStatus', type: 'GET', cache: false,
                        success: function (st) {
                            render(st);
                            progress(st);
                            if (st.status === 'running') {
                                if (st.mode && st.mode !== mode()) {
                                    say('text-muted', 'Another search (' + st.mode + ') is running.');
                                } else if (st.starting) {
                                    say('text-muted', 'Starting...');
                                } else {
                                    say('text-muted', 'Checked ' + (st.attempts || 0) + ' of at most ' + (st.max_attempts || '?') +
                                        ', verified ' + (st.verified || 0) + '...' +
                                        (warpSourcesText(st.sources) ? ' ' + warpSourcesText(st.sources) : ''));
                                }
                                return;
                            }
                            stop();
                            if (st.status === 'done' || st.status === 'cancelled') {
                                var n = st.verified || 0;
                                say(n > 0 ? 'text-success' : 'text-danger', (st.status === 'cancelled' ? 'Cancelled. ' : '') +
                                    (st.recheck ? 'Re-check finished: ' : 'Search finished: ') + n + ' verified of ' + (st.attempts || 0) +
                                    ' checked' + (n === 0 && !st.recheck ? '. Nothing answered; try another mode or more attempts.' : '.') +
                                    (warpSourcesText(st.sources) ? ' ' + warpSourcesText(st.sources) : ''));
                            } else if (st.status === 'error') {
                                say('text-danger', st.message || 'The search failed.');
                            }
                        },
                        error: function () { stop(); say('text-danger', 'Could not read the search state.'); }
                    });
                }
                function startPolling() {
                    if (polling === null) {
                        polling = setInterval(poll, 1000);
                    }
                    $wrap.find('.wp-start').prop('disabled', true);
                    running = true;
                    $dlg.find('.wp-cancel').show().prop('disabled', false);
                    $dlg.find('.wp-recheck-all').hide();
                }
                function stop() {
                    if (polling !== null) {
                        clearInterval(polling);
                        polling = null;
                    }
                    $wrap.find('.wp-start').prop('disabled', false);
                    running = false;
                    $dlg.find('.wp-cancel').hide();
                    $dlg.find('.wp-recheck-all').toggle(($wrap.data('rows') || []).length > 0);
                }

                function start(endpoints) {
                    var cred = credentials(kind);
                    var lack = missing(kind, cred);
                    if (lack.length) {
                        say('text-danger', 'Fill in first: ' + lack.join(', ') + '.');
                        return;
                    }
                    var data = { mode: mode(), credentials: cred, zero_trust: $wrap.find('.wp-zt').is(':checked') ? '1' : '0',
                                 ignore_cache: $wrap.find('.wp-ignore').is(':checked') ? '1' : '0',
                                 want: $wrap.find('.wp-want').val(), max_attempts: $wrap.find('.wp-max').val() };
                    if ($wrap.find('.wp-src').is(':checked')) {
                        data.use_sources = '1';
                        data.any_address = $wrap.find('.wp-any').is(':checked') ? '1' : '0';
                    }
                    if (kind !== 'wg' && $wrap.find('.wp-wide').is(':checked')) {
                        data.wide = '1';
                    }
                    if (kind !== 'wg' && $wrap.find('.wp-fm').is(':checked')) {
                        data.fm = fmValues();
                    }
                    if (endpoints && endpoints.length) {
                        data.endpoints = endpoints;
                    }
                    say('text-muted', 'Starting...');
                    progress(null);
                    $dlg.find('.wp-table tbody').empty();
                    $dlg.find('.wp-table, .wp-empty').hide();
                    $dlg.find('.modal-title').text('Find working endpoint: ' + (endpoints && endpoints.length ? 'checking ' + endpoints.length + ' saved' : (kind === 'wg' ? 'WireGuard' : 'MASQUE')));
                    openDialog();
                    startPolling();
                    $.ajax({ url: '/api/xrayclient/service/warpProbeStart', type: 'POST', data: data, timeout: 30000,
                        success: function (res) {
                            if (!res || res.status !== 'ok') {
                                stop();
                                say('text-danger', (res && res.message) || 'The search did not start.');
                            }
                        },
                        error: function () { stop(); say('text-danger', 'The request failed.'); }
                    });
                }

                var srcKey = kind === 'wg' ? 'osxray_warp_src' : 'osxray_warp_src_masque';
                try {
                    $wrap.find('.wp-src').prop('checked', window.localStorage.getItem(srcKey) === '1');
                } catch (e) { /* storage unavailable: the box simply starts unchecked */ }
                // The URL list is a plugin setting (xrayclient.maintenance.warp_sources),
                // edited here, next to the search that uses it.
                var srcLoaded = false;
                function showSrcBox() {
                    var on = $wrap.find('.wp-src').is(':checked');
                    $wrap.find('.wp-src-box').toggle(on);
                    if (on && !srcLoaded) {
                        srcLoaded = true;
                        ajaxCall('/api/xrayclient/settings/get', {}, function (res) {
                            var m = res && res.xrayclient && res.xrayclient.maintenance;
                            $wrap.find('.wp-src-urls').val((m && m.warp_sources) || '').data('saved', (m && m.warp_sources) || '');
                        });
                    }
                }
                showSrcBox();
                $wrap.find('.wp-src').on('change', function () {
                    try {
                        window.localStorage.setItem(srcKey, this.checked ? '1' : '0');
                    } catch (e) { /* ignore */ }
                    showSrcBox();
                });
                $wrap.find('.wp-src-urls').on('change', function () {
                    var $ta = $(this);
                    var $msg = $wrap.find('.wp-src-msg');
                    var value = $.trim($ta.val() || '');
                    $msg.attr('class', 'wp-src-msg text-muted').text('Saving...');
                    ajaxCall('/api/xrayclient/settings/set', { xrayclient: { maintenance: { warp_sources: value } } }, function (res) {
                        if (res && res.result === 'saved') {
                            $ta.val(value).data('saved', value);
                            $msg.attr('class', 'wp-src-msg text-success').text('Saved.');
                        } else {
                            var v = res && res.validations;
                            var text = v ? Object.keys(v).map(function (k) { return v[k]; }).join(' ') : 'The list was not saved.';
                            $msg.attr('class', 'wp-src-msg text-danger').text(text);
                        }
                    });
                });
                $wrap.find('.wp-start').on('click', function () { start(null); });
                $wrap.find('.wp-show').on('click', function (e) {
                    e.preventDefault();
                    openDialog();
                });
                $dlg.find('.wp-recheck-all').on('click', function () {
                    var rows = ($wrap.data('rows') || []).filter(function (r) { return r.status !== 'failed'; });
                    start(rows.map(function (r) { return { host: r.host, port: r.port }; }));
                });
                $dlg.find('.wp-cancel').on('click', function () {
                    $.ajax({ url: '/api/xrayclient/service/warpProbeCancel', type: 'POST' });
                    $(this).prop('disabled', true);
                    say('text-muted', 'Cancelling...');
                });
                $wrap.find('.wp-opts-toggle').on('click', function (e) {
                    e.preventDefault();
                    $wrap.find('.wp-opts').toggle();
                });
                $wrap.find('input[name=warp_probe_mode]').on('change', function () { poll(); });
                // show what is known when the dialog opens; resume a running search
                $('#DialogNode').on('shown.bs.modal', function () {
                    if (kind === 'masque') {
                        var alpn = $('#node\\.alpn').val() || [];
                        $wrap.find('input[name=warp_probe_mode][value=' + (alpn.length && alpn.indexOf('h2') === -1 ? 'masque_h3' : 'masque_h2') + ']').prop('checked', true);
                    }
                    $.ajax({ url: '/api/xrayclient/service/warpProbeStatus', type: 'GET', cache: false,
                        success: function (st) {
                            render(st);
                            progress(st);
                            var mine = kind === 'wg' ? st.mode === 'wg' : /^masque_/.test(st.mode || '');
                            if (st.status === 'running' && mine) {
                                startPolling();
                            }
                        } });
                });
            }

            build('wg', $('#node\\.wg_endpoint').closest('tr, .form-group'));
            build('masque', $('#masque_warp_tools'));
        })();

        // Capture phase: runs before the bootgrid save handler; a bad raw
        // JSON field aborts the save and highlights the offending input.
        (function installNodeRawJsonGuard() {
            var btn = document.getElementById('btn_DialogNode_save');
            if (!btn) {
                return;
            }
            btn.addEventListener('click', function (event) {
                var err = nodeRawJsonError();
                if (!err) {
                    return;
                }
                event.preventDefault();
                event.stopImmediatePropagation();
                $('.json-invalid').removeClass('json-invalid');
                var $field = $(err.selector);
                // The offending field may sit in a collapsed section or behind
                // the advanced switch: open both so the error is visible.
                var $sec = $field.closest('.collapse-section');
                if ($sec.length) {
                    setSectionCollapsed($sec, false);
                }
                if ($('#DialogNode').hasClass('optional-hidden') && $field.hasClass('expert_only')) {
                    $('#DialogNode').removeClass('optional-hidden');
                    if (window.osxrayNodeAdvanced) {
                        window.osxrayNodeAdvanced.set(true);
                    }
                }
                $field.addClass('json-invalid').trigger('focus');
                showJsonSectionError(err.label + ': ' + err.message, 'Invalid JSON field');
            }, true);
            $(document).on('input', '.json-invalid', function () {
                $(this).removeClass('json-invalid');
            });
        })();

        // Rules, Balancers and Policy & Sniffing are sub-tabs of Routing:
        // bring the parent tab to the front first.
        function showTab(href) {
            if (['#tab_rules', '#tab_balancers', '#tab_routing_policy'].indexOf(href) !== -1) {
                $('a[href="#tab_routing"]').tab('show');
            }
            $('a[href="' + href + '"]').tab('show');
        }

        $('.btn_save_apply').on('click', function () {
            var jsonError = jsonSectionError();
            if (jsonError) {
                showJsonSectionError(jsonError);
                return;
            }
            var $btn = $(this);
            var originalHtml = $btn.html();
            $btn.prop('disabled', true).find('.fa-spinner').show();
            // The settings are spread over several forms (General, Routing,
            // DNS, Balancers, Expert Config, Maintenance); they are saved one after the
            // other and the first form with a validation error is brought to
            // the front, so the error is not hidden on another tab.
            var saveSteps = [
                ['frm_general', '#tab_general'],
                ['frm_general_dns', '#tab_dns'],
                ['frm_general_obs', '#tab_balancers'],
                ['frm_general_route', '#tab_routing_policy'],
                ['frm_general_expert', '#tab_expert'],
                ['frm_maintenance', '#tab_maintenance']
            ];
            function saveStep(i) {
                if (i >= saveSteps.length) {
                    return applyAfterSave();
                }
                saveFormToEndpoint("/api/xrayclient/settings/set", saveSteps[i][0], function () {
                    if (i === 0) {
                        // (re)start background telemetry polling with the new interval
                        startTelemetryAutoRefresh();
                    }
                    saveStep(i + 1);
                }, false, function () {
                    showTab(saveSteps[i][1]);
                    $btn.html(originalHtml).prop('disabled', false);
                });
            }
            saveStep(0);
            function applyAfterSave() {
                ajaxCall("/api/xrayclient/service/reconfigure", {}, function (data) {
                    updateServiceControlUI('xrayclient');
                    if (data && data.status === 'ok') {
                        $btn.html('<b>Applied <span class="fa fa-check"></span></b>');
                        setTimeout(function () {
                            $btn.html(originalHtml).prop('disabled', false);
                        }, 1500);
                    } else {
                        $btn.html('<b>Failed — see logs</b>');
                        setTimeout(function () {
                            $btn.html(originalHtml).prop('disabled', false);
                        }, 2500);
                    }
                });
            }
        });

        function loadVersionInfo() {
            ajaxCall('/api/xrayclient/service/version', {}, function (data) {
                if (data) {
                    $('#lbl_core_version').text(data.core_version || 'Unknown');
                    $('#lbl_geodata_date').text(data.geodata_date || 'Unknown');
                    $('#lbl_plugin_version').text(data.plugin_version || 'unknown');
                }
            });
        }

        function renderUpdateRow(prefix, info) {
            $('#upd_' + prefix + '_current').text(info.current || 'unknown');
            $('#upd_' + prefix + '_latest').text(info.latest || 'unreachable');
            var $badge = $('#upd_' + prefix + '_badge');
            if (!info.latest) {
                $badge.html('<span class="label label-default">offline</span>');
            } else if (info.updateAvailable) {
                $badge.html('<span class="label label-warning">update available</span>');
            } else {
                $badge.html('<span class="label label-success">up to date</span>');
            }
            var $link = $('#upd_' + prefix + '_link');
            if (info.releaseUrl) {
                $link.attr('href', info.releaseUrl).show();
            } else {
                $link.hide();
            }
        }

        var updatesInFlight = false;
        function checkForUpdates() {
            if (updatesInFlight) {
                return;
            }
            updatesInFlight = true;
            $('#lbl_updates_status').text('Checking GitHub…').removeClass('text-danger').addClass('text-muted');
            ajaxCall('/api/xrayclient/service/checkUpdates', {}, function (data) {
                updatesInFlight = false;
                if (!data || data.status !== 'ok') {
                    $('#lbl_updates_status').text('Check failed' + ((data && data.message) ? ': ' + data.message : '')).removeClass('text-muted').addClass('text-danger');
                    return;
                }
                renderUpdateRow('core', data.core || {});
                renderUpdateRow('plugin', data.plugin || {});
                $('#updates_details').show();
                if (data.message) {
                    $('#lbl_updates_status').text(data.message).removeClass('text-muted').addClass('text-warning');
                } else {
                    $('#lbl_updates_status').text('Checked ' + (data.checkedAt || '')).removeClass('text-danger').addClass('text-muted');
                }
            });
        }

        $('#btn_check_updates').on('click', checkForUpdates);
        $('a[href="#tab_maintenance"]').on('shown.bs.tab', refreshPluginBranches);
        $('a[href="#tab_maintenance"]').on('shown.bs.tab', loadVersionInfo);
        $('a[href="#tab_maintenance"]').on('shown.bs.tab', checkForUpdates);

        $('#btn_update_core').on('click', function () {
            $('#maintenance_output').text('Updating Xray-core binary from GitHub... Please wait.').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
                ajaxCall('/api/xrayclient/service/updateCore', {}, function (res) {
                    $('#maintenance_output').text(res.output || 'Update finished.');
                    loadVersionInfo();
                    updateServiceControlUI('xrayclient');
                });
            });
        });

        $('#btn_update_geodata').on('click', function () {
            $('#maintenance_output').text('Downloading geoip.dat and geosite.dat... Please wait.').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
                ajaxCall('/api/xrayclient/service/updateGeodata', {}, function (res) {
                    $('#maintenance_output').text(res.output || 'GeoData update finished.');
                    loadVersionInfo();
                });
            });
        });

        $('#btn_update_plugin').on('click', function () {
            $('#maintenance_output').text('Pulling os-xray-client plugin code (branch ' + ($('[id="xrayclient.maintenance.plugin_branch"]').val() || 'main') + ') from GitHub...').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
                ajaxCall('/api/xrayclient/service/updatePlugin', {}, function (res) {
                    $('#maintenance_output').text(res.output || 'Plugin updated. Reloading page in 3 seconds...');
                    setTimeout(function () { location.reload(); }, 3000);
                });
            });
        });

    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general"><b>General Settings</b></a></li>
    <li><a data-toggle="tab" href="#tab_nodes"><b>Outbound Nodes (Servers)</b></a></li>
    <li><a data-toggle="tab" href="#tab_routing"><b>Routing</b></a></li>
    <li><a data-toggle="tab" href="#tab_dns"><b>DNS Servers</b></a></li>
    <li id="tab_expert_li" style="display: none;"><a data-toggle="tab" href="#tab_expert"><b>Expert Config</b></a></li>
    <li><a data-toggle="tab" href="#tab_maintenance"><b>Maintenance &amp; Updates</b></a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general']) }}
            <div id="json_sections_container" style="display:none;">
                <div class="form-group">
                    <label for="xrayclient.general.dns_json"><b>Built-in DNS — top-level <code>dns</code> object</b></label>
                    <textarea id="xrayclient.general.dns_json" class="form-control json_section" rows="6" spellcheck="false" placeholder='{ "servers": ["https://1.1.1.1/dns-query", "1.1.1.1"], "queryStrategy": "UseIP" }'></textarea>
                    <span class="help-block">Fallback path, used only when <b>Enable Built-in DNS</b> (above) is off — an enabled built-in DNS takes precedence and this field is ignored. When set, Xray resolves domains for routing through this DNS instead of the system resolver. Server formats: an IP, <code>tcp://ip</code>, <code>https://host/dns-query</code> (DoH), <code>https+local://host/dns-query</code> (DoH without a detour), <code>localhost</code>, <code>fakedns</code>. Supports <code>hosts</code>, <code>queryStrategy</code>, <code>disableCache</code>, <code>tag</code>. A wrong DNS breaks domain-based routing, so start with a minimal list.</span>
                </div>
                <div class="form-group">
                    <label for="xrayclient.general.balancers_json"><b>Load Balancers — <code>routing.balancers</code> array</b></label>
                    <textarea id="xrayclient.general.balancers_json" class="form-control json_section" rows="6" spellcheck="false" placeholder='[ { "tag": "auto", "selector": ["node_"], "strategy": { "type": "leastPing" }, "fallbackTag": "direct" } ]'></textarea>
                    <span class="help-block">Each entry needs <code>tag</code>, <code>selector</code> and <code>strategy.type</code> (<code>random</code>, <code>roundRobin</code>, <code>leastPing</code>, <code>leastLoad</code>). <code>selector</code> matches outbound tags by prefix, so <code>"node_"</code> covers every node. <code>leastPing</code> and <code>leastLoad</code> also need an observatory (see Load Balancer Observatory below); a rule can use a balancer only by its <code>tag</code>.</span>
                </div>
                <div class="form-group">
                    <label for="xrayclient.general.observatory_json"><b>Observatory — top-level <code>observatory</code> / <code>burstObservatory</code></b></label>
                    <textarea id="xrayclient.general.observatory_json" class="form-control json_section" rows="6" spellcheck="false" placeholder='{ "burstObservatory": { "subjectSelector": ["node_"], "pingConfig": { "destination": "https://connectivitycheck.gstatic.com/generate_204", "interval": "1m", "sampling": 10 } } }'></textarea>
                    <span class="help-block">The object is inserted at the top level of <code>config.json</code>, so it must contain <code>observatory</code> and/or <code>burstObservatory</code>. The observatory probes the nodes with HTTP and feeds <code>leastPing</code> / <code>leastLoad</code>; <code>subjectSelector</code> also matches tags by prefix.</span>
                </div>
                <div class="form-group">
                    <label for="xrayclient.general.dns_hosts_json"><b>Static Hosts (built-in DNS) — <code>dns.hosts</code> object</b></label>
                    <textarea id="xrayclient.general.dns_hosts_json" class="form-control json_section" rows="6" spellcheck="false" placeholder='{ "example.com": "192.0.2.10", "internal.lan": ["192.0.2.11", "192.0.2.12"] }'></textarea>
                    <span class="help-block">Map of domains to addresses, answered without any DNS query. Only used when <b>Enable Built-in DNS</b> is on. Keys accept the full domain (internally matched by <code>full</code>); values may be a single address or an array. Checked with JSON.parse; leave empty to omit.</span>
                </div>
            </div>
            <div class="col-md-12">
                <hr/>
                <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                    <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
                </button>
            </div>
        </div>
    </div>

    <div id="tab_nodes" class="tab-pane fade in">
        <div id="nodes_toolbar" class="col-md-12" style="margin-bottom: 10px;">
            <button id="btn_open_import_modal" type="button" class="btn btn-default">
                <i class="fa fa-paste"></i> Import link
            </button>
            <button id="btn_check_nodes" type="button" class="btn btn-default">
                <i class="fa fa-refresh"></i> Check latency &amp; traffic
            </button>
            <span id="live_traffic_wrap" style="margin-left: 14px; user-select: none; vertical-align: middle;">
                <label style="display: inline-flex; align-items: center; gap: 6px; cursor: pointer; font-weight: normal; margin: 0;">
                    <input type="checkbox" id="live_traffic_toggle" style="margin: 0;"> Live <span id="live_traffic_interval" class="text-muted"></span><span id="live_traffic_dot" class="live-traffic-dot" style="margin: 0;"></span>
                </label>
            </span>
        </div>
        <table id="grid-nodes" class="table table-condensed table-hover table-striped" data-editDialog="DialogNode">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="3.5em" data-type="string" data-formatter="rowtoggle">Active</th>
                    <th data-column-id="name" data-min-width="8em" data-type="string">Server Name</th>
                    <th data-column-id="protocol" data-min-width="13em" data-formatter="nodetype">Type</th>
                    <th data-column-id="address" data-min-width="14em" data-formatter="nodeendpoint">Endpoint</th>
                    <th data-column-id="latency" data-width="6em" data-formatter="latency" data-sortable="false">Latency</th>
                    <th data-column-id="traffic" data-width="10em" data-formatter="traffic" data-sortable="false">Traffic &#8595;/&#8593;</th>
                    <th data-column-id="commands" data-width="8em" data-formatter="commands" data-sortable="false">Actions</th>
                </tr>
            </thead>
            <tbody></tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-primary command-add"><span class="fa fa-fw fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-fw fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
        <div class="col-md-12" style="padding-bottom: 15px;">
        <div id="telemetry_total_row">
            <span id="telemetry_total" class="text-muted"></span>
        </div>
        <div style="margin: 14px 0 8px 0;">
            <span class="text-muted" style="font-size: 15px; line-height: 1.5;">Entries here are saved immediately on every add/edit/delete/toggle. <b>Apply &amp; Restart Xray</b> rebuilds config.json and restarts Xray.</span>
        </div>
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_routing" class="tab-pane fade in">
        <ul class="nav nav-pills" id="routingtabs">
            <li class="active"><a data-toggle="tab" href="#tab_rules"><b>Rules</b></a></li>
            <li><a data-toggle="tab" href="#tab_balancers"><b>Balancers</b></a></li>
            <li><a data-toggle="tab" href="#tab_routing_policy"><b>Policy &amp; Sniffing</b></a></li>
        </ul>
        <div class="tab-content">
    <div id="tab_rules" class="tab-pane fade in active">
        <table id="grid-rules" class="table table-condensed table-hover table-striped" data-editDialog="DialogRule">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">Enabled</th>
                    <th data-column-id="sequence" data-width="4em" data-type="numeric" data-formatter="ruleseq">#</th>
                    <th data-column-id="description" data-type="string">Description</th>
                    <th data-column-id="domain" data-type="string" data-formatter="rulematch" data-sortable="false">Match</th>
                    <th data-column-id="outbound_tag" data-width="10em" data-type="string">Action (Outbound)</th>
                    <th data-column-id="commands" data-width="12em" data-formatter="commands" data-sortable="false">Actions</th>
                </tr>
            </thead>
            <tbody></tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-primary"><span class="fa fa-fw fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-fw fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
        <div class="col-md-12" style="padding-bottom: 15px;">
        <div style="margin: 14px 0 8px 0;">
            <span class="text-muted" style="font-size: 15px; line-height: 1.5;">Rules are applied top-to-bottom (&#8593;/&#8595; to reorder). Entries save instantly &mdash; click <b>Apply &amp; Restart Xray</b>.</span>
        </div>
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_balancers" class="tab-pane fade in">
        {{ partial("layout_partials/base_form", ['fields': observatoryForm, 'id': 'frm_general_obs']) }}
        <table id="grid-balancers" class="table table-condensed table-hover table-striped" data-editDialog="DialogBalancer">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">Enabled</th>
                    <th data-column-id="tag" data-width="12em" data-type="string">Tag</th>
                    <th data-column-id="selector" data-type="string">Node Selector (tag prefixes)</th>
                    <th data-column-id="strategy" data-width="12em" data-type="string">Strategy</th>
                    <th data-column-id="fallback_tag" data-width="12em" data-type="string">Fallback</th>
                    <th data-column-id="commands" data-width="10em" data-formatter="commands" data-sortable="false">Actions</th>
                </tr>
            </thead>
            <tbody></tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-primary"><span class="fa fa-fw fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-fw fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
        <div class="col-md-12" style="margin-top: 6px; margin-bottom: 2px;">
            <button id="btn_balancer_info" type="button" class="btn btn-info btn-xs" title="Ask the Xray RoutingService (xray api bi) which outbound each balancer currently selects, per the observatory measurements this minute.">
                <i class="fa fa-signal"></i> <b>Show live selection</b>
            </button>
            <span style="margin-left: 10px; font-size: 12px;" class="text-muted">LeastPing needs a reachable observatory; the answer is empty until the first probe completes.</span>
        </div>
        <div class="col-md-12" id="balancer_info_output" style="display: none; margin-bottom: 6px;"></div>
        <div class="col-md-12" style="padding-bottom: 15px;">
        <div style="margin: 14px 0 8px 0;">
            <span class="text-muted" style="font-size: 15px; line-height: 1.5;">A balancer groups nodes by tag prefix and picks one for every connection. Rules choose it from the &laquo;Balancers&raquo; group in Target Outbound. leastPing / leastLoad need an observatory (Load Balancer Observatory above). Entries save instantly &mdash; click <b>Apply &amp; Restart Xray</b>.</span>
        </div>
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_routing_policy" class="tab-pane fade in">
        {{ partial("layout_partials/base_form", ['fields': routingForm, 'id': 'frm_general_route']) }}
        <div class="col-md-12" style="padding-bottom: 15px;">
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>
        </div>
    </div>

    <div id="tab_dns" class="tab-pane fade in">
        {{ partial("layout_partials/base_form", ['fields': dnsForm, 'id': 'frm_general_dns']) }}
        <div id="dns_empty_state" class="alert alert-info" style="display:none; margin-top: 10px; padding-top: 12px; padding-bottom: 12px;">
            <b>No DNS servers yet.</b> The built-in DNS needs at least one resolver here. Use the <b>+</b> button above the table — the dialog offers built-in presets (Cloudflare / Google / AdGuard DoH, Yandex, system resolver) or a custom server.
        </div>
        <table id="grid-dns" class="table table-condensed table-hover table-striped" data-editDialog="DialogDnsServer">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">Enabled</th>
                    <th data-column-id="address" data-width="18em" data-type="string">Address</th>
                    <th data-column-id="port" data-width="5em" data-type="string">Port</th>
                    <th data-column-id="domains" data-type="string">Domains</th>
                    <th data-column-id="expected_ips" data-type="string">Expected IPs</th>
                    <th data-column-id="commands" data-width="10em" data-formatter="commands" data-sortable="false">Actions</th>
                </tr>
            </thead>
            <tbody></tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-primary"><span class="fa fa-fw fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-fw fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
        <div class="col-md-12" style="padding-bottom: 15px;">
        <div style="margin: 14px 0 8px 0;">
            <span class="text-muted" style="font-size: 15px; line-height: 1.5;">Switch on <b>Enable Built-in DNS</b> above, then list resolvers here. Servers with a domains list answer only those domains; the preset in the dialog fills typical setups. Entries save instantly &mdash; <b>Apply &amp; Restart Xray</b>.</span>
        </div>
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves the plugin settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_expert" class="tab-pane fade">
        {{ partial("layout_partials/base_form", ['fields': expertForm, 'id': 'frm_general_expert']) }}
            <div id="raw_json_container" style="display:none; padding: 0 15px 15px 15px; margin-top: 10px;">
                <label for="xrayclient.general.raw_json"><b>Raw Xray JSON Configuration (/usr/local/etc/xray/config.json):</b></label>
                <textarea id="xrayclient.general.raw_json" class="form-control" rows="16" style="font-family: monospace; font-size: 12px;" placeholder="{ &quot;inbounds&quot;: [...], &quot;outbounds&quot;: [...] }"></textarea>
            </div>
        <div class="col-md-12" style="margin-top: 15px; padding-bottom: 15px;">
            <div class="alert alert-warning" style="margin-bottom: 10px;">
                <b>Expert Mode.</b> This is the exact <code>/usr/local/etc/xray/config.json</code> Xray is running (or would run). Saving here validates the JSON with <code>xray run -test</code>, stores a backup next to the file (<code>config.json.bak-*</code>), switches the plugin to <b>Raw JSON</b> mode and restarts Xray. The UI tabs will no longer regenerate the file. Use <b>Reset to template-generated config</b> to switch back to template-based generation (UI Builder) without losing nodes or rules.
            </div>
            <div class="form-inline" style="margin-bottom: 8px;">
                <button id="btn_expert_refresh" type="button" class="btn btn-default"><i class="fa fa-refresh"></i> <b>Refresh</b></button>
                <button id="btn_expert_edit" type="button" class="btn btn-info"><i class="fa fa-pencil"></i> <b>Edit manually</b></button>
                <button id="btn_expert_save" type="button" class="btn btn-primary" style="display: none;"><i class="fa fa-save"></i> <b>Save &amp; Apply</b> <i class="fa fa-spinner fa-pulse" id="expert_save_spin" style="display: none;"></i></button>
                <button id="btn_expert_cancel" type="button" class="btn btn-default" style="display: none;">Cancel</button>
                <button id="btn_expert_reset" type="button" class="btn btn-warning" title="Back up the current config.json, switch the plugin back to UI Builder mode, regenerate /usr/local/etc/xray/config.json from the built-in template, validate and restart Xray. Nodes and rules are kept; raw_json stays stored but is not used."><i class="fa fa-undo"></i> <b>Reset to template-generated config</b></button>
                <span id="expert_config_status" class="text-muted" style="margin-left: 12px;"></span>
            </div>
            <div id="expert_view_wrap">
                <pre id="expert_config_view" style="max-height: 560px; overflow: auto; background: #1e1e1e; color: #d4d4d4; padding: 12px; border-radius: 4px; font-size: 12px; white-space: pre;">Loading…</pre>
            </div>
            <div id="expert_edit_wrap" style="display: none;">
                <textarea id="expert_config_edit" class="form-control" spellcheck="false" style="width: 100%; height: 560px; font-family: Consolas, Menlo, monospace; font-size: 12px; white-space: pre;"></textarea>
                <div id="expert_edit_error" class="alert alert-danger" style="display: none; margin-top: 8px; margin-bottom: 0;"></div>
            </div>
        </div>
    </div>

    <div id="tab_maintenance" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 15px;">
            <div class="alert alert-info">
                <b>Installed Xray-core Version:</b> <span id="lbl_core_version">Loading...</span> &nbsp;|&nbsp;
                <b>GeoData Last Updated:</b> <span id="lbl_geodata_date">Loading...</span> &nbsp;|&nbsp;
                <b>Plugin Version:</b> <span id="lbl_plugin_version">&hellip;</span>
            </div>
        </div>
        <div class="col-md-12">
            <div style="border: 1px solid rgba(255,255,255,0.08); border-radius: 4px; padding: 12px 15px; margin-bottom: 10px; background: rgba(255,255,255,0.02);">
                <div class="form-inline" style="margin-bottom: 0;">
                    <button id="btn_check_updates" type="button" class="btn btn-default"><i class="fa fa-refresh"></i> <b>Check for Updates</b></button>
                    <span id="lbl_updates_status" class="text-muted" style="margin-left: 12px;">Not checked yet.</span>
                </div>
                <div id="updates_details" style="display: none; margin-top: 12px; font-size: 13px;">
                    <div style="margin-bottom: 6px;">
                        <b>Xray-core:</b> <span id="upd_core_current"></span> &nbsp;→&nbsp; <span id="upd_core_latest"></span>
                        <span id="upd_core_badge" style="margin-left: 8px;"></span>
                        <a id="upd_core_link" href="#" target="_blank" rel="noopener" style="margin-left: 8px; display: none;">release notes</a>
                    </div>
                    <div>
                        <b>Plugin:</b> <span id="upd_plugin_current"></span> &nbsp;→&nbsp; <span id="upd_plugin_latest"></span>
                        <span id="upd_plugin_badge" style="margin-left: 8px;"></span>
                        <a id="upd_plugin_link" href="#" target="_blank" rel="noopener" style="margin-left: 8px; display: none;">GitHub</a>
                    </div>
                </div>
            </div>
        </div>
        {{ partial("layout_partials/base_form", ['fields': maintenanceForm, 'id': 'frm_maintenance']) }}
        <div class="col-md-12">
            <button id="btn_update_core" type="button" class="btn btn-warning">
                <i class="fa fa-cloud-download"></i> <b>Download &amp; Update Xray-core</b>
            </button>
            <button id="btn_update_geodata" type="button" class="btn btn-info">
                <i class="fa fa-globe"></i> <b>Update GeoIP &amp; GeoSite Now</b>
            </button>
            <button id="btn_update_plugin" type="button" class="btn btn-success">
                <i class="fa fa-github"></i> <b>Update Plugin from GitHub</b>
            </button>
        </div>
        <div class="col-md-12" style="padding-bottom: 15px;">
            <pre id="maintenance_output" style="display:none; margin-top: 15px; max-height: 300px; overflow-y: auto;"></pre>
        </div>
    </div>
</div>

{{ partial("layout_partials/base_dialog", ['fields': formDialogNode, 'id': 'DialogNode', 'label': 'Edit Outbound Server Node']) }}
{{ partial("layout_partials/base_dialog", ['fields': formDialogRule, 'id': 'DialogRule', 'label': 'Edit Routing Rule']) }}
{{ partial("layout_partials/base_dialog", ['fields': formDialogBalancer, 'id': 'DialogBalancer', 'label': 'Edit Load Balancer']) }}
{{ partial("layout_partials/base_dialog", ['fields': formDialogDnsServer, 'id': 'DialogDnsServer', 'label': 'Edit DNS Server']) }}

<div class="modal fade" id="DialogResetTemplate" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title">Reset to template-generated config</h4>
            </div>
            <div class="modal-body">
                <p><b>What will happen:</b></p>
                <ul style="margin-bottom: 8px;">
                    <li>Current <code>/usr/local/etc/xray/config.json</code> is backed up next to the file (<code>config.json.bak-*</code>).</li>
                    <li>The plugin switches back to <b>UI Builder</b> mode (template generation is re-attached).</li>
                    <li><code>/usr/local/etc/xray/config.json</code> is regenerated from the built-in template (your nodes and routing rules are kept).</li>
                    <li>The file is validated with <code>xray run -test</code> and Xray is restarted. If the test fails, the previous config is restored.</li>
                </ul>
                <p class="text-muted" style="margin-bottom: 0;">Your stored raw JSON (<code>raw_json</code>) is not deleted, it is just not used while the plugin is in UI Builder mode.</p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>
                <button type="button" id="btn_confirm_reset_template" class="btn btn-warning"><i class="fa fa-undo"></i> Reset &amp; Apply</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="DialogImportLink" tabindex="-1" role="dialog">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title">Import VLESS / Trojan / Shadowsocks Link or Raw JSON</h4>
            </div>
            <div class="modal-body">
                <p>Paste a <code>vless://...</code>, <code>vmess://...</code>, <code>trojan://...</code>, <code>ss://...</code> or <code>hysteria2://...</code> URI link below to automatically populate the server configuration fields, or paste a complete JSON configuration object:</p>
                <textarea id="import_link_input" class="form-control" rows="6" style="font-family: monospace;" placeholder="vless://uuid@server:443?encryption=none&amp;flow=xtls-rprx-vision&amp;security=reality&amp;sni=...&amp;fp=chrome&amp;pbk=...&amp;sid=...&amp;type=tcp#MyServer"></textarea>
                <div id="import_error_msg" class="alert alert-danger" style="display:none; margin-top: 10px;"></div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>
                <button type="button" id="btn_parse_and_fill" class="btn btn-primary"><i class="fa fa-check"></i> Parse &amp; Open Editor</button>
            </div>
        </div>
    </div>
</div>

