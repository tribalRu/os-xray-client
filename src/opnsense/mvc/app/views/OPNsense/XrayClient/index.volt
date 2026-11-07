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
        max-width: 900px;
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
    /* The OPNsense base_dialog partial renders a third, 35%-wide column
       reserved for validation messages (span.help-block). When empty it
       shows up as a useless grey sidebar. Collapse it while every
       help-block is empty; it re-appears automatically as soon as a
       validation message is inserted (see MutationObserver setup). */
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
</style>

<script>
    $(document).ready(function () {
        mapDataToFormUI({
            'frm_general': "/api/xrayclient/settings/get",
            'frm_maintenance': "/api/xrayclient/settings/get"
        }).done(function (data) {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            toggleConfigModeUI();
            toggleGeoDataCustomUI();
            startTelemetryAutoRefresh();
            if (typeof toggleExpertTab === 'function') {
                toggleExpertTab($('#xrayclient\\.general\\.expert_mode').prop('checked'));
            }
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
            $('#DialogNode, #DialogRule').each(function () {
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
                '<div id="rule_preset_container" style="padding: 12px 15px 0 15px; border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 10px; margin-bottom: 5px;">' +
                    '<label for="rule_preset" style="width: 100%; margin-bottom: 4px;"><b>Start from a built-in preset</b></label>' +
                    '<select id="rule_preset" class="form-control">' +
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
                $('#rule\\.enabled').prop('checked', true);
                $('#rule\\.sequence').val(p.sequence);
                $('#rule\\.description').val(p.description);
                setTokens('domain', p.domain);
                setTokens('ip', p.ip);
                $('#rule\\.network_proto').val('tcp_udp').selectpicker('refresh');
                $('#rule\\.outbound_tag').val(p.outbound_tag).selectpicker('refresh');
            });
        })();

        // Expert Config tab: view the effective /usr/local/etc/xray/config.json
        // or edit it manually. Saving routes through saveRawConfigAction
        // (validate -> backup -> xray run -test -> atomic write -> restart).
        window.toggleExpertTab = function toggleExpertTab(show) {
            $('#tab_expert_li').toggle(!!show);
            if (!show && $('a[href="#tab_expert"]').parent().hasClass('active')) {
                $('a[href="#tab_general"]').tab('show');
            }
        };

        $('#xrayclient\\.general\\.expert_mode').on('change', function () {
            toggleExpertTab($(this).prop('checked'));
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

        // The Raw JSON textarea is rendered outside the generated
        // <form id="frm_general">. saveFormToEndpoint() only serialises
        // fields inside that form, so move the container inside it or
        // Raw JSON would never be saved to config.xml.
        $('#frm_general').append($('#raw_json_container'));

        function toggleConfigModeUI() {
            var mode = $('#xrayclient\\.general\\.config_mode').val();
            if (mode === 'raw') {
                $('#raw_json_container').show();
            } else {
                $('#raw_json_container').hide();
            }
        }
        $('#xrayclient\\.general\\.config_mode').on('change', toggleConfigModeUI);

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

            // Hysteria and MASQUE transport is implied by the protocol.
            var effNet = isHysteria ? 'hysteria' : (isMasque ? 'masque' : net);
            var effSec = (isHysteria || isMasque) ? 'tls' : sec;

            setBlock('.proto_endpoint', hasEndpoint);
            setBlock('.proto_password', hasPassword);
            setBlock('.proto_auth', hasAuth);

            setBlock('.proto_vless', proto === 'vless');
            setBlock('.proto_vmess', proto === 'vmess');
            setBlock('.proto_shadowsocks', proto === 'shadowsocks');
            setBlock('.proto_wireguard', proto === 'wireguard');
            setBlock('.proto_freedom', proto === 'freedom');
            setBlock('.proto_blackhole', proto === 'blackhole');
            setBlock('.proto_dns', proto === 'dns');
            setBlock('.proto_loopback', proto === 'loopback');
            setBlock('.proto_hysteria', isHysteria);
            setBlock('.proto_masque', isMasque);
            setBlock('.proto_http_masque', proto === 'http' || isMasque);

            setBlock('.proto_transport', hasTransport);
            setBlock('.transport_selector', hasStream);
            setBlock('.stream_custom', hasStream);
            setBlock('.mux_supported', hasMux);

            setBlock('.net_ws', hasStream && effNet === 'ws');
            setBlock('.net_grpc', hasStream && effNet === 'grpc');
            setBlock('.net_xhttp', hasStream && effNet === 'xhttp');
            setBlock('.net_httpupgrade', hasStream && effNet === 'httpupgrade');

            setBlock('.sec_tls', hasTransport && effSec === 'tls');
            setBlock('.sec_reality', hasTransport && effSec === 'reality');
        }

        $('#node\\.protocol, #node\\.network, #node\\.security').on('change', toggleNodeDialogFields);

        var nodeLatencyCache = {};
        var nodeTrafficCache = {};

        function formatBytes(bytes) {
            if (!bytes || bytes <= 0) return '0 B';
            var k = 1024;
            var sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            var i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
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
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-check-square-o command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-square-o command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    },
                    "latency": function (column, row) {
                        var info = nodeLatencyCache[row.uuid];
                        if (!info) return '<span class="label label-default">Unchecked</span>';
                        if (info.status === 'online') {
                            var color = info.ms < 150 ? 'label-success' : (info.ms < 350 ? 'label-warning' : 'label-danger');
                            return '<span class="label ' + color + '">' + info.ms + ' ms</span>';
                        }
                        return '<span class="label label-danger">Offline</span>';
                    },
                    "traffic": function (column, row) {
                        var t = nodeTrafficCache[row.uuid];
                        if (!t) return '<small class="text-muted">↓ 0 B / ↑ 0 B</small>';
                        return '<small><span class="text-success">↓ ' + formatBytes(t.downlink) + '</span> / <span class="text-info">↑ ' + formatBytes(t.uplink) + '</span></small>';
                    }
                }
            }
        });

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
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-check-square-o command-toggle bootgrid-tooltip" data-value="1" data-row-id="' + row.uuid + '"></span>';
                        } else {
                            return '<span style="cursor: pointer;" class="fa fa-fw fa-square-o command-toggle bootgrid-tooltip" data-value="0" data-row-id="' + row.uuid + '"></span>';
                        }
                    }
                }
            }
        });

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
            $('#node\\.encryption').val(data.encryption || 'none');
            setSelectValue($('#node\\.ss_method'), data.ss_method);
            setSelectValue($('#node\\.vmess_security'), data.vmess_security);
            $('#node\\.vmess_experiments').val(data.vmess_experiments);
            setSelectValue($('#node\\.network'), data.network);
            setSelectValue($('#node\\.security'), data.security);
            $('#node\\.sni').val(data.sni);
            setSelectValue($('#node\\.fingerprint'), data.fingerprint);
            fillTokenizeField('#node\\.alpn', data.alpn);
            $('#node\\.reality_pubkey').val(data.reality_pubkey);
            $('#node\\.reality_shortid').val(data.reality_shortid);
            $('#node\\.reality_spiderx').val(data.reality_spiderx);
            $('#node\\.transport_host').val(data.transport_host);
            $('#node\\.transport_path').val(data.transport_path);
            $('#node\\.grpc_service_name').val(data.grpc_service_name);
            setSelectValue($('#node\\.xhttp_mode'), data.xhttp_mode);

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

            $('#node\\.mux_enabled').prop('checked', data.mux_enabled == '1');

            $('#node\\.protocol').trigger('change');
            $('#node\\.network').trigger('change');
            $('#node\\.security').trigger('change');
            toggleNodeDialogFields();
        }

        $('#DialogNode').on('shown.bs.modal', function () {
            toggleNodeDialogFields();
            injectWarpButton();
            if (pendingImport) {
                var data = pendingImport;
                pendingImport = null;
                fillNodeDialog(data);
            }
        });

        // --- WARP auto-config generation for WireGuard ---
        // Injects a "Generate WARP config" button into the WireGuard section
        // of the node dialog. Clicking it calls the backend WARP generator
        // (keypair + Cloudflare WARP registration) and fills all WireGuard fields.
        function injectWarpButton() {
            if ($('#btn_warp_generate').length > 0) return;
            var $wgHeader = $('#DialogNode .modal-body .proto_wireguard').closest('table').prevAll('thead').find('b:contains("WireGuard Settings")');
            if ($wgHeader.length === 0) return;
            var $btn = $(
                '<button id="btn_warp_generate" type="button" class="btn btn-xs btn-info" style="margin-top:6px;">' +
                '<i class="fa fa-cloud-download"></i> <b>Generate WARP config</b>' +
                '<i id="btn_warp_generate_spin" class="fa fa-spinner fa-pulse" style="display:none; margin-left:6px;"></i>' +
                '</button> ' +
                '<span id="warp_gen_status" class="text-muted" style="margin-left:8px; font-size:12px;"></span>'
            );
            $wgHeader.closest('tr').after(
                '<tr><td colspan="3" style="text-align:left; padding-top:6px;">' +
                '<small style="color:#888;">Cloudflare WARP is a WireGuard-based service. This generates a local ' +
                'WireGuard keypair and registers with Cloudflare WARP to fill all fields.</small>' +
                '</td></tr>'
            );
            $wgHeader.closest('tr').next().find('td').append($btn);
            $btn.on('click', function () {
                generateWarpConfig();
            });
        }

        function generateWarpConfig() {
            var $btn = $('#btn_warp_generate');
            var $spin = $('#btn_warp_generate_spin');
            var $status = $('#warp_gen_status');
            $btn.prop('disabled', true);
            $spin.show();
            $status.text('Generating WireGuard keypair and registering with WARP…').show();
            ajaxCall('/api/xrayclient/service/warpGenerate', {}, function (data) {
                $btn.prop('disabled', false);
                $spin.hide();
                if (!data || data.status !== 'ok') {
                    $status.html('<span class="text-danger">Failed: ' + (data && data.message ? data.message : 'unknown error') + '</span>');
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
                    $status.html('<span class="text-success">WARP config generated. License: <b>' + data.license + '</b>. Save the node to apply.</span>');
                } else {
                    $status.html('<span class="text-success">WARP config generated. Save the node to apply.</span>');
                }
                if (data.warning) {
                    $status.append('<br/><small class="text-warning">' + data.warning + '</small>');
                }
                // Select WireGuard protocol if not already
                if ($('#node\\.protocol').val() !== 'wireguard') {
                    $('#node\\.protocol').val('wireguard').selectpicker('refresh').trigger('change');
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
                name: url.hash ? decodeURIComponent(url.hash.substring(1)) : remarkFallback,
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
                    $('#DialogImportLink').modal('hide');
                    $('a[href="#tab_general"]').tab('show');
                    return;
                } catch (e) {
                    $('#import_error_msg').text('Invalid JSON syntax: ' + e.message).show();
                    return;
                }
            }

            try {
                var url = new URL(raw);
                var proto = url.protocol.replace(':', '').toLowerCase();

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
                    throw new Error('Supported URI schemes: vless://, trojan://, ss:// (or paste a full JSON object).');
                }

                var params = url.searchParams;
                var remark = url.hash ? decodeURIComponent(url.hash.substring(1)) : (url.hostname + ':' + url.port);

                var netType = (params.get('type') || 'tcp').toLowerCase();
                if (netType === 'splithttp') netType = 'xhttp';
                if (netType === 'http') netType = 'httpupgrade';

                var alpn = params.get('alpn') || '';
                if (!alpn) {
                    var allAlpn = params.getAll('alpn');
                    if (allAlpn.length > 1) {
                        alpn = allAlpn.join(',');
                    }
                }

                pendingImport = {
                    name: remark,
                    protocol: proto,
                    address: url.hostname,
                    port: url.port || '443',
                    user_uuid: decodeURIComponent(url.username),
                    flow: params.get('flow') || 'none',
                    encryption: params.get('encryption') || 'none',
                    ss_method: 'x2022-blake3-aes-128-gcm',
                    network: netType,
                    security: (params.get('security') || 'none').toLowerCase(),
                    sni: params.get('sni') || params.get('serverName') || '',
                    fingerprint: params.get('fp') || 'chrome',
                    alpn: alpn,
                    reality_pubkey: params.get('pbk') || '',
                    reality_shortid: params.get('sid') || '',
                    reality_spiderx: params.get('spx') ? decodeURIComponent(params.get('spx')) : '/',
                    transport_host: params.get('host') || '',
                    transport_path: params.get('path') ? decodeURIComponent(params.get('path')) : '',
                    grpc_service_name: params.get('serviceName') || '',
                    xhttp_mode: (params.get('mode') && netType === 'xhttp') ? params.get('mode') : 'auto'
                };

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

        // --- Automatic telemetry (background refresh) ---
        // Traffic is refreshed at the user-configured interval. Latency is a
        // TCP connect probe, so it is measured less often on a separate
        // hardcoded timer (5 minutes) — it does not need constant polling.
        var trafficTimer = null;
        var latencyTimer = null;
        var LATENCY_AUTO_INTERVAL = 300; // seconds (5 min), hardcoded

        function telemetryStatus(trafficActive, trafficInterval, latencyActive) {
            var $s = $('#telemetry_status');
            var parts = [];
            if (trafficActive) parts.push('traffic: ' + trafficInterval + ' s');
            if (latencyActive) parts.push('latency: ' + LATENCY_AUTO_INTERVAL + ' s');
            var text = parts.length ? 'Auto: ' + parts.join('; ') : '';
            if ($s.length === 0) {
                if (text) {
                    $s = $('<span id="telemetry_status" class="label label-info" style="margin-left:8px;"></span>')
                        .insertAfter('#btn_check_nodes');
                }
            }
            if ($s.length) {
                if (text) { $s.text(text).show(); } else { $s.remove(); }
            }
        }

        function refreshNodeLatency() {
            ajaxCall('/api/xrayclient/service/healthcheck', {}, function (data) {
                if (data && data.nodes) {
                    nodeLatencyCache = data.nodes;
                    $('#grid-nodes').bootgrid('reload');
                }
            });
        }

        function refreshNodeTraffic() {
            ajaxCall('/api/xrayclient/service/stats', {}, function (data) {
                if (data && data.stats) {
                    nodeTrafficCache = data.stats;
                    $('#grid-nodes').bootgrid('reload');
                    updateTotalTraffic(data.stats);
                }
            });
        }

        function updateTotalTraffic(stats) {
            var totalDown = 0, totalUp = 0;
            $.each(stats, function (uuid, t) {
                totalDown += parseInt(t.downlink || 0, 10);
                totalUp += parseInt(t.uplink || 0, 10);
            });
            var $t = $('#telemetry_total');
            if ($t.length === 0) {
                $t = $('<span id="telemetry_total" style="margin-left:12px;"></span>')
                    .insertAfter('#btn_check_nodes');
            }
            $t.text('Total traffic: ↓ ' + formatBytes(totalDown) + ' / ↑ ' + formatBytes(totalUp));
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

        $('.btn_save_apply').on('click', function () {
            var $btn = $(this);
            var originalHtml = $btn.html();
            $btn.prop('disabled', true).find('.fa-spinner').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_general', function () {
                // (re)start background telemetry polling with the new interval
                startTelemetryAutoRefresh();
                saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
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
                });
            });
        });

        function loadVersionInfo() {
            ajaxCall('/api/xrayclient/service/version', {}, function (data) {
                if (data) {
                    $('#lbl_core_version').text(data.core_version || 'Unknown');
                    $('#lbl_geodata_date').text(data.geodata_date || 'Unknown');
                    $('#lbl_plugin_version').text(data.plugin_version || '1.2.5');
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
            $('#maintenance_output').text('Pulling latest os-xray-client plugin code from GitHub...').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
                ajaxCall('/api/xrayclient/service/updatePlugin', {}, function (res) {
                    $('#maintenance_output').text(res.output || 'Plugin updated. Reloading page in 3 seconds...');
                    setTimeout(function () { location.reload(); }, 3000);
                });
            });
        });

        function loadLogs() {
            var type = $('#log_type_select').val();
            $.get('/api/xrayclient/service/logs', { type: type, lines: 250 }, function (res) {
                $('#xray_log_content').text(res.log || 'No log entries found.');
            });
        }
        $('a[href="#tab_logs"]').on('shown.bs.tab', loadLogs);
        $('#btn_refresh_logs, #log_type_select').on('click change', loadLogs);
        $('#btn_clear_logs').on('click', function () {
            ajaxCall('/api/xrayclient/service/logs', { action: 'clear' }, function () {
                loadLogs();
            });
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general"><b>General Settings</b></a></li>
    <li><a data-toggle="tab" href="#tab_nodes"><b>Outbound Nodes (Servers)</b></a></li>
    <li><a data-toggle="tab" href="#tab_rules"><b>Routing Rules</b></a></li>
    <li id="tab_expert_li" style="display: none;"><a data-toggle="tab" href="#tab_expert"><b>Expert Config</b></a></li>
    <li><a data-toggle="tab" href="#tab_maintenance"><b>Maintenance &amp; Updates</b></a></li>
    <li><a data-toggle="tab" href="#tab_logs"><b>Log Viewer</b></a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general']) }}
            <div id="raw_json_container" style="display:none; padding: 0 15px 15px 15px;">
                <label for="xrayclient.general.raw_json"><b>Raw Xray JSON Configuration (/usr/local/etc/xray/config.json):</b></label>
                <textarea id="xrayclient.general.raw_json" class="form-control" rows="16" style="font-family: monospace; font-size: 12px;" placeholder="{ &quot;inbounds&quot;: [...], &quot;outbounds&quot;: [...] }"></textarea>
            </div>
            <div class="col-md-12">
                <hr/>
                <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves General + Maintenance settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                    <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
                </button>
            </div>
        </div>
    </div>

    <div id="tab_nodes" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 10px; margin-bottom: 4px;">
            <small class="text-muted">Entries here are saved immediately on every add/edit/delete/toggle. <b>Apply &amp; Restart Xray</b> rebuilds config.json and restarts Xray.</small>
        </div>
        <div class="col-md-12" style="margin-bottom: 10px;">
            <button id="btn_open_import_modal" type="button" class="btn btn-success">
                <i class="fa fa-paste"></i> <b>Import link</b>
            </button>
            <button id="btn_check_nodes" type="button" class="btn btn-info">
                <i class="fa fa-refresh"></i> <b>Check Latency (Ping) &amp; Traffic</b>
            </button>
        </div>
        <table id="grid-nodes" class="table table-condensed table-hover table-striped" data-editDialog="DialogNode">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">Active</th>
                    <th data-column-id="name" data-type="string">Server Name</th>
                    <th data-column-id="protocol" data-width="8em" data-type="string">Protocol</th>
                    <th data-column-id="address" data-type="string">Address</th>
                    <th data-column-id="port" data-width="6em" data-type="string">Port</th>
                    <th data-column-id="security" data-width="8em" data-type="string">Security</th>
                    <th data-column-id="latency" data-width="9em" data-formatter="latency" data-sortable="false">Latency</th>
                    <th data-column-id="traffic" data-width="14em" data-formatter="traffic" data-sortable="false">Traffic (DL / UL)</th>
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
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves General + Maintenance settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_rules" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 10px; margin-bottom: 4px;">
            <small class="text-muted">Rules are evaluated top-to-bottom by priority. Use the &#8593;/&#8595; arrows in the Actions column to reorder them. Add a built-in preset from the dialog via «Start from a built-in preset». Entries here are saved immediately; <b>Apply &amp; Restart Xray</b> rebuilds config.json and restarts Xray.</small>
        </div>
        <table id="grid-rules" class="table table-condensed table-hover table-striped" data-editDialog="DialogRule">
            <thead>
                <tr>
                    <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">ID</th>
                    <th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">Enabled</th>
                    <th data-column-id="sequence" data-width="6em" data-type="numeric">Seq</th>
                    <th data-column-id="description" data-type="string">Description</th>
                    <th data-column-id="domain" data-type="string">Domain / GeoSite</th>
                    <th data-column-id="ip" data-type="string">IP / GeoIP</th>
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
            <hr/>
            <button class="btn btn-primary btn_save_apply" type="button" title="Entries in this grid are saved immediately on every add/edit/delete. This button saves General + Maintenance settings, regenerates /usr/local/etc/xray/config.json from the UI template and restarts Xray.">
                <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_expert" class="tab-pane fade">
        <div class="col-md-12" style="margin-top: 15px; padding-bottom: 15px;">
            <div class="alert alert-warning" style="margin-bottom: 10px;">
                <b>Expert Mode.</b> This is the exact <code>/usr/local/etc/xray/config.json</code> Xray is running (or would run). Saving here validates the JSON with <code>xray run -test</code>, stores a backup next to the file (<code>config.json.bak-*</code>), switches the plugin to <b>Raw JSON</b> mode and restarts Xray. The UI tabs will no longer regenerate the file — switch back to <i>UI Builder</i> in General settings to restore template-based generation.
            </div>
            <div class="form-inline" style="margin-bottom: 8px;">
                <button id="btn_expert_refresh" type="button" class="btn btn-default"><i class="fa fa-refresh"></i> <b>Refresh</b></button>
                <button id="btn_expert_edit" type="button" class="btn btn-info"><i class="fa fa-pencil"></i> <b>Edit manually</b></button>
                <button id="btn_expert_save" type="button" class="btn btn-primary" style="display: none;"><i class="fa fa-save"></i> <b>Save &amp; Apply</b> <i class="fa fa-spinner fa-pulse" id="expert_save_spin" style="display: none;"></i></button>
                <button id="btn_expert_cancel" type="button" class="btn btn-default" style="display: none;">Cancel</button>
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
                <b>Plugin Version:</b> <span id="lbl_plugin_version">1.2.5</span>
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
        <div class="col-md-12" style="padding-bottom: 15px;">
            <button id="btn_update_core" type="button" class="btn btn-warning">
                <i class="fa fa-cloud-download"></i> <b>Download &amp; Update Xray-core</b>
            </button>
            <button id="btn_update_geodata" type="button" class="btn btn-info">
                <i class="fa fa-globe"></i> <b>Update GeoIP &amp; GeoSite Now</b>
            </button>
            <button id="btn_update_plugin" type="button" class="btn btn-success">
                <i class="fa fa-github"></i> <b>Update Plugin from GitHub</b>
            </button>
            <pre id="maintenance_output" style="display:none; margin-top: 15px; max-height: 300px; overflow-y: auto;"></pre>
        </div>
    </div>

    <div id="tab_logs" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 15px; margin-bottom: 15px;">
            <div class="form-inline" style="margin-bottom: 10px;">
                <select id="log_type_select" class="selectpicker" data-width="220px">
                    <option value="error">Error &amp; System Log (error.log)</option>
                    <option value="access">Access &amp; Routing Log (access.log)</option>
                </select>
                <button id="btn_refresh_logs" type="button" class="btn btn-default"><i class="fa fa-refresh"></i> Refresh</button>
                <button id="btn_clear_logs" type="button" class="btn btn-danger"><i class="fa fa-trash"></i> Clear Logs</button>
            </div>
            <pre id="xray_log_content" style="height: 480px; overflow-y: scroll; background: #1e1e1e; color: #d4d4d4; font-family: monospace; font-size: 12px; padding: 12px;"></pre>
        </div>
    </div>
</div>

{{ partial("layout_partials/base_dialog", ['fields': formDialogNode, 'id': 'DialogNode', 'label': 'Edit Outbound Server Node']) }}
{{ partial("layout_partials/base_dialog", ['fields': formDialogRule, 'id': 'DialogRule', 'label': 'Edit Routing Rule']) }}

<div class="modal fade" id="DialogImportLink" tabindex="-1" role="dialog">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title">Import VLESS / Trojan / Shadowsocks Link or Raw JSON</h4>
            </div>
            <div class="modal-body">
                <p>Paste a <code>vless://...</code>, <code>trojan://...</code> or <code>ss://...</code> URI link below to automatically populate the server configuration fields, or paste a complete JSON configuration object:</p>
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