<?php

namespace OPNsense\XrayClient;

use OPNsense\Base\BaseModel;
use OPNsense\Base\Messages\Message;

class XrayClient extends BaseModel
{
    /**
     * Cross-field checks the per-field masks cannot express:
     * - a local proxy with "password" authentication needs a user name and a
     *   password, otherwise Xray starts an inbound nobody can log in to;
     * - with "noauth" authentication the user name and password must be
     *   empty, otherwise stale credentials linger in a config that ignores
     *   them;
     * - balancer tags must be unique, because routing rules pick a balancer
     *   by tag alone;
     * - an XDRIVE node must satisfy the rules Xray enforces in
     *   infra/conf/xray.go (VLESS, non-none encryption, no flow, Mux.Cool)
     *   and carry the credentials of the selected storage backend.
     */
    public function performValidation($validateFullModel = false)
    {
        $messages = parent::performValidation($validateFullModel);

        $inbounds = [
            ['enable_socks', 'socks_auth', 'socks_username', 'socks_password'],
            ['enable_http', 'http_auth', 'http_username', 'http_password'],
        ];
        foreach ($inbounds as $names) {
            list($enable, $auth, $user, $pass) = $names;
            if ((string)$this->general->$enable !== '1') {
                continue;
            }
            $mode = (string)$this->general->$auth;
            if ($mode === 'password') {
                foreach ([$user, $pass] as $name) {
                    if (trim((string)$this->general->$name) === '') {
                        $messages->appendMessage(new Message(
                            gettext('Required when authentication is set to password.'),
                            $this->general->$name->__reference
                        ));
                    }
                }
            } elseif ($mode === 'noauth') {
                // Fail closed: with noauth the credentials are silently
                // ignored by Xray, so do not let them linger in the config.
                foreach ([$user, $pass] as $name) {
                    if (trim((string)$this->general->$name) !== '') {
                        $messages->appendMessage(new Message(
                            gettext('Must be empty when authentication is set to noauth.'),
                            $this->general->$name->__reference
                        ));
                    }
                }
            }
        }

        $seen = [];
        foreach ($this->balancers->balancer->iterateItems() as $balancer) {
            if ((string)$balancer->enabled !== '1') {
                continue;
            }
            $tag = trim((string)$balancer->tag);
            if ($tag === '') {
                continue;
            }
            if (isset($seen[$tag])) {
                $messages->appendMessage(new Message(
                    gettext('Balancer tags must be unique.'),
                    $balancer->tag->__reference
                ));
            }
            $seen[$tag] = true;
        }

        // XDRIVE is a VLESS-only transport and Xray refuses to start unless the
        // outbound matches these rules (see infra/conf/xray.go validateXDrive).
        // Checking here turns an opaque "xray run -test" failure into a field
        // error, and stops a half-configured node from being saved.
        foreach ($this->nodes->node->iterateItems() as $node) {
            if ((string)$node->enabled !== '1' || (string)$node->network !== 'xdrive') {
                continue;
            }
            if ((string)$node->protocol !== 'vless') {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport requires the VLESS protocol.'),
                    $node->protocol->__reference
                ));
            }
            $service = (string)$node->xdrive_service;
            if ($service === '') {
                $service = 'google-drive';
            }
            if ($service === 'google-drive' && (string)$node->security !== 'tls') {
                $messages->appendMessage(new Message(
                    gettext('XDRIVE over Google Drive requires TLS (with SNI, ALPN h2/h3 and a uTLS fingerprint).'),
                    $node->security->__reference
                ));
            }
            if ((string)$node->security === 'reality') {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport does not support REALITY; use TLS or None.'),
                    $node->security->__reference
                ));
            }
            if (!in_array(trim((string)$node->flow), ['', 'none'], true)) {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport does not support VLESS flow; set it to None.'),
                    $node->flow->__reference
                ));
            }
            $encryption = strtolower(trim((string)$node->encryption));
            if ($encryption === '' || $encryption === 'none') {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport needs VLESS encryption; generate one with "xray vlessenc".'),
                    $node->encryption->__reference
                ));
            }
            if ((string)$node->mux_enabled !== '1') {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport requires Mux.Cool to be enabled.'),
                    $node->mux_enabled->__reference
                ));
            }
            $concurrency = trim((string)$node->mux_concurrency);
            if ($concurrency !== '' && (int)$concurrency < 0) {
                $messages->appendMessage(new Message(
                    gettext('The XDRIVE transport requires mux concurrency >= 0; -1 disables mux.'),
                    $node->mux_concurrency->__reference
                ));
            }
            if (trim((string)$node->xdrive_remote_folder) === '') {
                $messages->appendMessage(new Message(
                    gettext('XDRIVE needs a remote folder (Drive folder ID, storage prefix, or local path).'),
                    $node->xdrive_remote_folder->__reference
                ));
            }
            if ($service === 'google-drive') {
                $required = [
                    'xdrive_google_client_id' => gettext('Google OAuth client ID'),
                    'xdrive_google_client_secret' => gettext('Google OAuth client secret'),
                    'xdrive_google_refresh_token' => gettext('Google OAuth refresh token'),
                ];
            } elseif ($service === 's3') {
                $required = [
                    'xdrive_s3_endpoint' => gettext('S3 endpoint'),
                    'xdrive_s3_bucket' => gettext('S3 bucket'),
                    'xdrive_s3_access_key' => gettext('S3 access key ID'),
                    'xdrive_s3_secret_key' => gettext('S3 secret access key'),
                ];
            } elseif ($service === 'template') {
                $required = [
                    'xdrive_template' => gettext('XDRIVE template JSON object'),
                ];
            } else {
                $required = [];
            }
            foreach ($required as $name => $label) {
                if (trim((string)$node->$name) === '') {
                    $messages->appendMessage(new Message(
                        sprintf(gettext('%s is required for the selected XDRIVE storage.'), $label),
                        $node->$name->__reference
                    ));
                }
            }
        }

        // MASQUE in Cloudflare WARP mode: the core needs the device key and
        // the assigned addresses, and either the edge public key or another
        // way to pin/verify the edge certificate.
        foreach ($this->nodes->node->iterateItems() as $node) {
            if ((string)$node->enabled !== '1' || (string)$node->protocol !== 'masque'
                || (string)$node->masque_mode !== 'warp') {
                continue;
            }
            $required = [
                'masque_warp_private_key' => gettext('WARP Private Key'),
                'masque_warp_address' => gettext('WARP Device Addresses'),
            ];
            foreach ($required as $name => $label) {
                if (trim((string)$node->$name) === '') {
                    $messages->appendMessage(new Message(
                        sprintf(gettext('%s is required for MASQUE in Cloudflare WARP mode.'), $label),
                        $node->$name->__reference
                    ));
                }
            }
            if (trim((string)$node->masque_warp_public_key) === ''
                && trim((string)$node->tls_pinned_peer_cert_sha256) === ''
                && trim((string)$node->tls_verify_peer_cert_by_name) === '') {
                $messages->appendMessage(new Message(
                    gettext('Set the WARP Edge Public Key, or pin the edge certificate with Pinned Peer Cert SHA-256 or Verify Peer Cert By Name.'),
                    $node->masque_warp_public_key->__reference
                ));
            }
        }

        // Raw JSON fields are spliced into config.json by the template, so a
        // malformed value would only surface as an `xray run -test` failure.
        $rawFields = [
            'extra' => 'object', 'xhttp_extra' => 'object', 'xdrive_extra' => 'object',
            'finalmask' => 'object', 'custom_stream_json' => 'object', 'http_headers' => 'object',
            'fm_tcp_extra_json' => 'object', 'fm_udp_extra_json' => 'object',
            'freedom_final_rules' => 'array', 'dns_rules_json' => 'array',
        ];
        foreach ($this->nodes->node->iterateItems() as $node) {
            if ((string)$node->enabled !== '1') {
                continue;
            }
            foreach ($rawFields as $name => $kind) {
                $problem = self::rawJsonProblem((string)$node->$name, $kind);
                if ($problem !== null) {
                    $messages->appendMessage(new Message($problem, $node->$name->__reference));
                }
            }
        }

        // FinalMask rows: the template builds the object, so enforce the
        // bounds the core documents (infra/conf/transport_finalmask.go).
        // Without this the only feedback is an opaque "xray run -test"
        // failure when Apply is pressed.
        foreach ($this->nodes->node->iterateItems() as $node) {
            if ((string)$node->enabled !== '1') {
                continue;
            }
            if (trim((string)$node->finalmask) !== '') {
                continue; // the raw override supersedes the rows
            }
            // UDP masks and the QUIC parameters only apply to QUIC-based
            // transports (Hysteria, MASQUE over HTTP/3, XHTTP over h3); the
            // dialog hides them elsewhere, so a stale hidden value must not
            // block the save.
            $alpn = array_map('trim', explode(',', (string)$node->alpn));
            $proto = (string)$node->protocol;
            $quicBased = $proto === 'hysteria'
                || ($proto === 'masque' && !in_array('h2', $alpn, true))
                || ($proto !== 'masque' && (string)$node->network === 'xhttp' && in_array('h3', $alpn, true));
            if (!$quicBased) {
                continue;
            }
            $udp = (string)$node->fm_udp_type;
            if ($udp === 'realm') {
                foreach (['fm_udp_realm_url', 'fm_udp_realm_stun_servers'] as $name) {
                    if (trim((string)$node->$name) === '') {
                        $messages->appendMessage(new Message(
                            gettext('Realm requires a realm:// URL and at least one STUN server.'),
                            $node->$name->__reference
                        ));
                    }
                }
            }
            $size = trim((string)$node->fm_udp_salamander_packet_size);
            if ($udp === 'salamander' && $size !== '' && preg_match('/^(\d+)(?:-(\d+))?$/', $size, $m)) {
                $high = isset($m[2]) ? (int)$m[2] : (int)$m[1];
                if ($high > 2048) {
                    $messages->appendMessage(new Message(
                        gettext('Salamander packet size must not exceed 2048 bytes.'),
                        $node->fm_udp_salamander_packet_size->__reference
                    ));
                }
            }
            $geckoSize = trim((string)$node->fm_udp_gecko_packet_size);
            if ($udp === 'gecko') {
                if (trim((string)$node->fm_udp_gecko_password) === '') {
                    $messages->appendMessage(new Message(
                        gettext('Gecko requires an obfuscation password shared with the server.'),
                        $node->fm_udp_gecko_password->__reference
                    ));
                }
                if ($geckoSize === '') {
                    $messages->appendMessage(new Message(
                        gettext('Gecko requires a packet size or range, e.g. 512 or 512-1200.'),
                        $node->fm_udp_gecko_packet_size->__reference
                    ));
                } elseif (preg_match('/^(\d+)(?:-(\d+))?$/', $geckoSize, $m)) {
                    $low = (int)$m[1];
                    $high = isset($m[2]) ? (int)$m[2] : (int)$m[1];
                    if ($low <= 0) {
                        $messages->appendMessage(new Message(
                            gettext('Gecko packet size must be at least 1 byte.'),
                            $node->fm_udp_gecko_packet_size->__reference
                        ));
                    } elseif ($high > 2048) {
                        $messages->appendMessage(new Message(
                            gettext('Gecko packet size must not exceed 2048 bytes.'),
                            $node->fm_udp_gecko_packet_size->__reference
                        ));
                    } elseif ($low > $high) {
                        $messages->appendMessage(new Message(
                            gettext('Gecko packet size range must be ascending, e.g. 512-1200.'),
                            $node->fm_udp_gecko_packet_size->__reference
                        ));
                    }
                }
            }
            $interval = trim((string)$node->fm_udp_udphop_interval);
            if ($udp === 'udphop' && $interval !== '' && preg_match('/^(\d+)/', $interval, $m) && (int)$m[1] < 5) {
                $messages->appendMessage(new Message(
                    gettext('UDP Hop interval must be at least 5 seconds.'),
                    $node->fm_udp_udphop_interval->__reference
                ));
            }
            if ($udp === 'udphop') {
                $modes = array_filter(array_map('trim', explode(',', (string)$node->fm_udp_udphop_mode)));
                if (count(array_intersect($modes, ['intervalremote', 'perconnremote'])) > 0) {
                    foreach (['fm_udp_udphop_remote_ips', 'fm_udp_udphop_remote_ports'] as $name) {
                        if (trim((string)$node->$name) === '') {
                            $messages->appendMessage(new Message(
                                gettext('The remote UDP Hop modes need both Remote IPs and Remote Ports.'),
                                $node->$name->__reference
                            ));
                        }
                    }
                }
                if ($interval !== '' && preg_match('/^(\d+)-(\d+)$/', $interval, $m) && (int)$m[1] > (int)$m[2]) {
                    $messages->appendMessage(new Message(
                        gettext('UDP Hop interval range must be ascending, e.g. 5-10.'),
                        $node->fm_udp_udphop_interval->__reference
                    ));
                }
            }
            $limits = [
                'fm_quic_max_idle_timeout' => [4, 120, gettext('Max idle timeout must be between 4 and 120 seconds.')],
                'fm_quic_keep_alive_period' => [2, 60, gettext('KeepAlive period must be between 2 and 60 seconds.')],
                'fm_quic_max_incoming_streams' => [8, 0, gettext('Max incoming streams must be at least 8.')],
                'fm_quic_init_stream_window' => [16384, 0, gettext('QUIC receive windows must be at least 16384 bytes.')],
                'fm_quic_max_stream_window' => [16384, 0, gettext('QUIC receive windows must be at least 16384 bytes.')],
                'fm_quic_init_conn_window' => [16384, 0, gettext('QUIC receive windows must be at least 16384 bytes.')],
                'fm_quic_max_conn_window' => [16384, 0, gettext('QUIC receive windows must be at least 16384 bytes.')],
            ];
            foreach ($limits as $name => $limit) {
                $value = trim((string)$node->$name);
                if ($value === '' || !ctype_digit($value)) {
                    continue;
                }
                $number = (int)$value;
                if ($number < $limit[0] || ($limit[1] > 0 && $number > $limit[1])) {
                    $messages->appendMessage(new Message($limit[2], $node->$name->__reference));
                }
            }
            if ((string)$node->fm_quic_congestion === 'force-brutal'
                && trim((string)$node->fm_quic_brutal_up) === '') {
                $messages->appendMessage(new Message(
                    gettext('Force Brutal requires an upload rate.'),
                    $node->fm_quic_brutal_up->__reference
                ));
            }
        }

        return $messages;
    }

    /**
     * Describes what is wrong with a raw JSON field, or null when it is empty
     * or a valid JSON object/array of at most 8192 characters.
     */
    public static function rawJsonProblem($raw, $kind)
    {
        $raw = trim((string)$raw);
        if ($raw === '') {
            return null;
        }
        if (strlen($raw) > 8192) {
            return gettext('Must be at most 8192 characters.');
        }
        $data = json_decode($raw, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return sprintf(gettext('Invalid JSON: %s.'), json_last_error_msg());
        }
        $isList = is_array($data) && ($data === [] || array_keys($data) === range(0, count($data) - 1));
        if ($kind === 'array' && !$isList) {
            return gettext('Must be a JSON array, e.g. [ { ... } ].');
        }
        if ($kind === 'object' && (!is_array($data) || ($isList && $data !== []))) {
            return gettext('Must be a JSON object, e.g. { ... }.');
        }
        return null;
    }
}
