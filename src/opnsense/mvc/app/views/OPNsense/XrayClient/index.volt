<style>
    #DialogNode .modal-body,
    #DialogRule .modal-body {
        max-height: calc(100vh - 210px);
        overflow-y: auto;
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
        });

        updateServiceControlUI('xrayclient');

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
            if (preset === 'custom') {
                $('.geodata_custom').closest('tr').show();
            } else {
                $('.geodata_custom').closest('tr').hide();
            }
        }
        $('#xrayclient\\.maintenance\\.geodata_preset').on('change', toggleGeoDataCustomUI);

        function toggleNodeDialogFields() {
            var proto = $('#node\\.protocol').val();
            var net = $('#node\\.network').val();
            var sec = $('#node\\.security').val();

            $('.proto_vless, .proto_shadowsocks').closest('tr').hide();
            if (proto === 'vless') $('.proto_vless').closest('tr').show();
            if (proto === 'shadowsocks') $('.proto_shadowsocks').closest('tr').show();

            $('.net_ws, .net_grpc, .net_xhttp, .net_httpupgrade').closest('tr').hide();
            if (net === 'ws') $('.net_ws').closest('tr').show();
            if (net === 'grpc') $('.net_grpc').closest('tr').show();
            if (net === 'xhttp') $('.net_xhttp').closest('tr').show();
            if (net === 'httpupgrade') $('.net_httpupgrade').closest('tr').show();

            $('.sec_tls, .sec_reality').closest('tr').hide();
            if (sec === 'tls') $('.sec_tls').closest('tr').show();
            if (sec === 'reality') $('.sec_reality').closest('tr').show();
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
            toggle: '/api/xrayclient/settings/toggleRule/'
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

        function fillNodeDialog(data) {
            $('body').addClass('modal-open');
            $('#node\\.enabled').prop('checked', true);
            $('#node\\.name').val(data.name);
            setSelectValue($('#node\\.protocol'), data.protocol);
            $('#node\\.address').val(data.address);
            $('#node\\.port').val(data.port || '443');
            $('#node\\.uuid').val(data.uuid);
            setSelectValue($('#node\\.flow'), data.flow);
            $('#node\\.encryption').val(data.encryption || 'none');
            setSelectValue($('#node\\.ss_method'), data.ss_method);
            setSelectValue($('#node\\.network'), data.network);
            setSelectValue($('#node\\.security'), data.security);
            $('#node\\.sni').val(data.sni);
            setSelectValue($('#node\\.fingerprint'), data.fingerprint);
            // Tokenize input accepts a comma-joined string.
            if (data.alpn) {
                $('#node\\.alpn').val(data.alpn);
                if (typeof formatTokenizersUI === 'function') {
                    formatTokenizersUI();
                }
                $('.selectpicker').selectpicker('refresh');
            }
            $('#node\\.reality_pubkey').val(data.reality_pubkey);
            $('#node\\.reality_shortid').val(data.reality_shortid);
            $('#node\\.reality_spiderx').val(data.reality_spiderx);
            $('#node\\.transport_host').val(data.transport_host);
            $('#node\\.transport_path').val(data.transport_path);
            $('#node\\.grpc_service_name').val(data.grpc_service_name);
            setSelectValue($('#node\\.xhttp_mode'), data.xhttp_mode);
            $('#node\\.protocol').trigger('change');
            $('#node\\.network').trigger('change');
            $('#node\\.security').trigger('change');
        }

        $('#DialogNode').on('shown.bs.modal', function () {
            toggleNodeDialogFields();
            if (pendingImport) {
                var data = pendingImport;
                pendingImport = null;
                fillNodeDialog(data);
            }
        });

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
                uuid: decodeURIComponent(password),
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
                    uuid: decodeURIComponent(url.username),
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

        $('#btn_seed_rules').on('click', function () {
            ajaxCall('/api/xrayclient/settings/seedDefaultRules', {}, function () {
                $('#grid-rules').bootgrid('reload');
            });
        });

        $('.btn_save_apply').on('click', function () {
            var $btn = $(this);
            $btn.find('.fa-spinner').show();
            saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_general', function () {
                saveFormToEndpoint("/api/xrayclient/settings/set", 'frm_maintenance', function () {
                    ajaxCall("/api/xrayclient/service/reconfigure", {}, function () {
                        updateServiceControlUI('xrayclient');
                        $btn.find('.fa-spinner').hide();
                    });
                });
            });
        });

        function loadVersionInfo() {
            ajaxCall('/api/xrayclient/service/version', {}, function (data) {
                if (data) {
                    $('#lbl_core_version').text(data.core_version || 'Unknown');
                    $('#lbl_geodata_date').text(data.geodata_date || 'Unknown');
                    $('#lbl_plugin_version').text(data.plugin_version || '1.0.1');
                }
            });
        }
        $('a[href="#tab_maintenance"]').on('shown.bs.tab', loadVersionInfo);

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
                <button class="btn btn-primary btn_save_apply" type="button">
                    <b>Apply &amp; Restart Xray</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
                </button>
            </div>
        </div>
    </div>

    <div id="tab_nodes" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 10px; margin-bottom: 10px;">
            <button id="btn_open_import_modal" type="button" class="btn btn-success">
                <i class="fa fa-paste"></i> <b>Import vless://, trojan://, ss:// or JSON</b>
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
                    <th data-column-id="latency" data-width="9em" data-formatter="latency" data-sortable="false">Availability</th>
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
            <button class="btn btn-primary btn_save_apply" type="button">
                <b>Apply Changes</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_rules" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 10px; margin-bottom: 10px;">
            <button id="btn_seed_rules" type="button" class="btn btn-default">
                <i class="fa fa-magic"></i> <b>Add Default RU Bypass Rules (geoip:ru, geosite:ru, private)</b>
            </button>
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
                    <th data-column-id="commands" data-width="8em" data-formatter="commands" data-sortable="false">Actions</th>
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
            <button class="btn btn-primary btn_save_apply" type="button">
                <b>Apply Routing Rules</b> <i class="fa fa-spinner fa-pulse" style="display: none;"></i>
            </button>
        </div>
    </div>

    <div id="tab_maintenance" class="tab-pane fade in">
        <div class="col-md-12" style="margin-top: 15px;">
            <div class="alert alert-info">
                <b>Installed Xray-core Version:</b> <span id="lbl_core_version">Loading...</span> &nbsp;|&nbsp;
                <b>GeoData Last Updated:</b> <span id="lbl_geodata_date">Loading...</span> &nbsp;|&nbsp;
                <b>Plugin Version:</b> <span id="lbl_plugin_version">1.0.1</span>
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