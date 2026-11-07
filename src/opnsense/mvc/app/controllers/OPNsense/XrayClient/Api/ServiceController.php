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

    /**
     * Return the effective Xray configuration (read-only view for the
     * Expert Config tab). Values are shown to the authenticated user only
     * (same exposure as the Raw JSON textarea).
     */
    public function getConfigAction()
    {
        $file = '/usr/local/etc/xray/config.json';
        if (!is_readable($file)) {
            return [
                'status' => 'error',
                'message' => 'config.json does not exist yet; apply the configuration first.'
            ];
        }
        $content = @file_get_contents($file);
        if ($content === false) {
            return ['status' => 'error', 'message' => 'Failed to read ' . $file];
        }
        return [
            'status' => 'ok',
            'path' => $file,
            'content' => $content
        ];
    }

    /**
     * Save a manually-edited Xray configuration (Expert Config tab).
     * Validates JSON, writes the file (with a timestamped backup of the
     * previous one), re-tests it with `xray run -test` and restarts the
     * service. On test failure the backup is restored. The plugin is
     * switched to Raw JSON mode and raw_json is updated, so later
     * "Apply & Restart" keeps the manually-written configuration.
     */
    public function saveRawConfigAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => 'POST required'];
        }

        $content = (string)$this->request->getPost('content', null, '');
        if (trim($content) === '') {
            return ['status' => 'error', 'message' => 'Empty configuration supplied.'];
        }

        json_decode($content, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return ['status' => 'error', 'message' => 'Invalid JSON: ' . json_last_error_msg()];
        }

        $file = '/usr/local/etc/xray/config.json';
        $backup = $file . '.bak-' . date('Ymd-His');
        @mkdir(dirname($file), 0755, true);

        // Back up the current config before overwriting it.
        if (file_exists($file)) {
            if (!@copy($file, $backup)) {
                return ['status' => 'error', 'message' => 'Failed to back up existing config.json'];
            }
        } else {
            $backup = null;
        }        $tmp = $file . '.tmp';
        if (file_put_contents($tmp, $content) === false || !rename($tmp, $file)) {
            @unlink($tmp);
            return ['status' => 'error', 'message' => 'Failed to write ' . $file];
        }
        @chmod($file, 0640);

        // Validate the written config with Xray itself.
        $backend = new Backend();
        $testOut = $backend->configdRun('xrayclient test_config');
        $testData = json_decode(trim($testOut), true);
        $testOk = is_array($testData) && (($testData['status'] ?? '') === 'ok');
        if (!$testOk) {
            // Roll back to the previous configuration.
            if ($backup !== null) {
                @copy($backup, $file);
            } else {
                @unlink($file);
            }
            $message = is_array($testData) ? ($testData['message'] ?? 'Xray config test failed') : trim($testOut);
            return ['status' => 'error', 'message' => $message];
        }

        // Persist raw mode so future Applies keep the manual config.
        $mdl = new XrayClient();
        $mdl->general->raw_json = $content;
        $mdl->general->config_mode = 'raw';
        try {
            $mdl->serializeToConfig();
            \OPNsense\Core\Config::getInstance()->save();
        } catch (\Throwable $e) {
            return [
                'status' => 'error',
                'message' => 'Config was written and tested, but saving plugin settings failed: ' . preg_replace('/\s+/', ' ', $e->getMessage())
            ];
        }

        if ((string)$mdl->general->enabled === '1') {
            $backend->configdRun('xrayclient restart');
        }

        return ['status' => 'ok', 'message' => 'Configuration saved, validated and applied.'];
    }

    public function healthcheckAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('xrayclient healthcheck');
        $data = json_decode($response, true);
        return is_array($data) ? $data : ['status' => 'error', 'nodes' => []];
    }

    /**
     * Generate a Cloudflare WARP WireGuard configuration.
     * Generates a local WireGuard keypair, registers with Cloudflare's WARP API,
     * and returns all fields to fill the WireGuard node dialog.
     */
    public function warpGenerateAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => 'POST required'];
        }

        $script = '/usr/local/opnsense/scripts/OPNsense/XrayClient/warp.py';
        if (!is_executable($script)) {
            return [
                'status' => 'error',
                'message' => 'WARP generator script not found or not executable (' . $script . ')',
            ];
        }

        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];
        $process = proc_open('python3 ' . escapeshellarg($script), $descriptors, $pipes);
        if (!is_resource($process)) {
            return ['status' => 'error', 'message' => 'Failed to start WARP generator script'];
        }

        // Non-blocking pipes so we can poll with a timeout instead of hanging
        // forever if the WARP API is unreachable.
        stream_set_blocking($pipes[1], 0);
        stream_set_blocking($pipes[2], 0);

        // Wait for the script to finish, but abort after 25 seconds so the
        // UI never hangs waiting on a slow/unreachable WARP API.
        $deadline = time() + 25;
        $stdout = $stderr = '';
        while (time() < $deadline) {
            $status = proc_get_status($process);
            if (!$status['running']) {
                break;
            }
            // Drain whatever is available without blocking.
            $stdout .= fread($pipes[1], 8192);
            $stderr .= fread($pipes[2], 8192);
            usleep(200000);
        }

        // Read any remaining output after the process exited.
        $stdout .= stream_get_contents($pipes[1]);
        $stderr .= stream_get_contents($pipes[2]);

        if (proc_get_status($process)['running']) {
            proc_terminate($process);
            return [
                'status' => 'error',
                'message' => 'WARP generator timed out after 25 seconds '
                    . '(Cloudflare API unreachable). Check outbound HTTPS to '
                    . 'api.cloudflareclient.com.',
            ];
        }

        $rc = proc_close($process);

        if ($rc !== 0) {
            return [
                'status' => 'error',
                'message' => 'WARP generator exited with code ' . $rc
                    . ': ' . trim($stderr),
            ];
        }

        $data = json_decode(trim($stdout), true);
        if (!is_array($data)) {
            return [
                'status' => 'error',
                'message' => 'WARP generator returned invalid output: ' . trim($stdout) . ' ' . trim($stderr),
            ];
        }

        return $data;
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
            'plugin_version' => '1.2.8'
        ];
    }

    public function checkUpdatesAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('xrayclient check_updates');
        $data = json_decode(trim($response), true);
        return is_array($data) ? $data : [
            'status' => 'error',
            'message' => 'Update check failed; see /var/log for details.'
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
        $repoUrl = 'https://github.com/tribalRu/os-xray-client';
        $branch = 'main';

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
