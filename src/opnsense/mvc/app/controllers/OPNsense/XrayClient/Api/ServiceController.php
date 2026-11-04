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
            return ['status' => 'failed'];
        }

        $backend = new Backend();
        $mdl = new XrayClient();

        $backend->configdRun('template reload OPNsense/XrayClient');

        if ((string)$mdl->general->config_mode === 'raw') {
            $rawJson = (string)$mdl->general->raw_json;
            if (!empty($rawJson)) {
                @mkdir('/usr/local/etc/xray', 0755, true);
                file_put_contents('/usr/local/etc/xray/config.json', $rawJson);
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
            'plugin_version' => '1.0.0'
        ];
    }

    public function updateCoreAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error'];
        }
        $mdl = new XrayClient();
        $branch = (string)$mdl->maintenance->core_branch ?: 'stable';
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

        $backend = new Backend();
        $output = $backend->configdpRun('xrayclient update_plugin', [$repoUrl, $branch]);
        return ['status' => 'ok', 'output' => $output];
    }

    public function logsAction()
    {
        $logType = $this->request->get('type', 'string', 'error');
        $lines = $this->request->get('lines', 'int', 200);
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
