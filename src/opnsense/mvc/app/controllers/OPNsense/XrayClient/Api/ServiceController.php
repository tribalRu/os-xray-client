<?php

namespace OPNsense\XrayClient\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;
use OPNsense\XrayClient\XrayClient;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\XrayClient\XrayClient';
    protected static $internalServiceTemplate = 'OPNsense/XrayClient';
    protected static $internalServiceEnabled = 'general.enabled';
    protected static $internalServiceName = 'xrayclient';

    public function reconfigureAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed', 'message' => 'POST required'];
        }

        $backend = new Backend();
        $mdl = new XrayClient();

        $backend->configdRun('template reload OPNsense/XrayClient');

        if ((string)$mdl->general->config_mode === 'raw') {
            $rawJson = trim((string)$mdl->general->raw_json);
            if ($rawJson !== '') {
                json_decode($rawJson, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    return [
                        'status' => 'error',
                        'message' => 'Raw JSON is not valid: ' . json_last_error_msg()
                    ];
                }
                @mkdir('/usr/local/etc/xray', 0755, true);
                $tmp = '/usr/local/etc/xray/.config.json.tmp';
                if (file_put_contents($tmp, $rawJson) === false) {
                    return ['status' => 'error', 'message' => 'Failed to write Xray config'];
                }
                chmod($tmp, 0640);
                if (!rename($tmp, '/usr/local/etc/xray/config.json')) {
                    @unlink($tmp);
                    return ['status' => 'error', 'message' => 'Failed to replace Xray config'];
                }
            }
        }

        // Validate the (re)generated config before (re)starting.
        if ((string)$mdl->general->enabled === '1') {
            $testOut = $backend->configdRun('xrayclient test_config');
            $testData = json_decode(trim($testOut), true);
            if (is_array($testData) && ($testData['status'] ?? '') !== 'ok') {
                return [
                    'status' => 'error',
                    'message' => $testData['message'] ?? 'Xray config test failed'
                ];
            }
            if (!is_array($testData) && trim($testOut) !== '') {
                // Old configd responses are plain text; treat non-empty
                // error-looking output as failure only when it decodes
                // to an explicit error (handled above). Plain text from
                // historical builds falls through to configdRun below.
            }
        }

        if ((string)$mdl->general->enabled === '1') {
            $backend->configdRun('xrayclient restart');
        } else {
            $backend->configdRun('xrayclient stop');
        }

        return ['status' => 'ok'];
    }

    public function healthcheckAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('xrayclient healthcheck');
        $data = json_decode($response, true);
        return is_array($data) ? $data : ['status' => 'error', 'nodes' => []];
    }

    public function statsAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('xrayclient stats');
        $data = json_decode($response, true);
        return is_array($data) ? $data : ['status' => 'error', 'stats' => []];
    }

    public function versionAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('xrayclient version');
        $data = json_decode($response, true);
        return is_array($data) ? $data : [
            'core_version' => 'Not installed',
            'geodata_date' => 'N/A',
            'plugin_version' => '1.0.2'
        ];
    }

    public function updateCoreAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error'];
        }
        $mdl = new XrayClient();
        $branch = (string)$mdl->maintenance->core_branch ?: 'stable';
        if (!in_array($branch, ['stable', 'latest'], true)) {
            return ['status' => 'error', 'message' => 'Invalid core branch'];
        }
        $backend = new Backend();
        $output = $backend->configdpRun('xrayclient update_core', [$branch]);
        return ['status' => 'ok', 'output' => $output];
    }

    public function updateGeodataAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error'];
        }
        $mdl = new XrayClient();
        $preset = (string)$mdl->maintenance->geodata_preset ?: 'runetfreedom';
        $geoipUrl = (string)$mdl->maintenance->custom_geoip_url ?: 'none';
        $geositeUrl = (string)$mdl->maintenance->custom_geosite_url ?: 'none';

        $backend = new Backend();
        $output = $backend->configdpRun('xrayclient update_geodata', [$preset, $geoipUrl, $geositeUrl]);
        return ['status' => 'ok', 'output' => $output];
    }

    public function updatePluginAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error'];
        }
        $mdl = new XrayClient();
        $repoUrl = (string)$mdl->maintenance->plugin_repo_url;
        $branch = (string)$mdl->maintenance->plugin_repo_branch ?: 'main';

        // Only allow GitHub https URLs and safe branch names; the updater
        // executes install.sh from the fetched archive.
        if (!preg_match('#^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$#', $repoUrl)) {
            return ['status' => 'error', 'message' => 'Plugin repo URL must be https://github.com/owner/repo'];
        }
        if (!preg_match('#^[A-Za-z0-9_.-]+$#', $branch)) {
            return ['status' => 'error', 'message' => 'Invalid plugin branch name'];
        }

        $backend = new Backend();
        $output = $backend->configdpRun('xrayclient update_plugin', [$repoUrl, $branch]);
        return ['status' => 'ok', 'output' => $output];
    }

    public function logsAction()
    {
        $logType = $this->request->get('type', 'string', 'error');
        if (!in_array($logType, ['error', 'access'], true)) {
            $logType = 'error';
        }
        $lines = (int)$this->request->get('lines', 'int', 200);
        if ($lines < 1) {
            $lines = 200;
        } elseif ($lines > 1000) {
            $lines = 1000;
        }
        if ($this->request->isPost() && $this->request->getPost('action') === 'clear') {
            $backend = new Backend();
            $backend->configdRun('xrayclient clear_logs');
            return ['status' => 'cleared', 'log' => ''];
        }

        $backend = new Backend();
        $output = $backend->configdpRun('xrayclient get_logs', [$logType, (string)$lines]);
        return ['status' => 'ok', 'log' => $output];
    }
}
