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
            if ((string)$this->general->$enable !== '1' || (string)$this->general->$auth !== 'password') {
                continue;
            }
            foreach ([$user, $pass] as $name) {
                if (trim((string)$this->general->$name) === '') {
                    $messages->appendMessage(new Message(
                        gettext('Required when authentication is set to password.'),
                        $this->general->$name->__reference
                    ));
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

        return $messages;
    }
}
