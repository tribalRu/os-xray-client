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

        // Remember the config that is currently on disk (and being used by the
        // running service) so it can be put back if the new one is rejected.
        $configFile = '/usr/local/etc/xray/config.json';
        $previousConfig = is_file($configFile) ? @file_get_contents($configFile) : false;

        $renderStatus = trim((string)$backend->configdRun('template reload OPNsense/XrayClient'));

        // The configd template handler reports failures as "ERR". In UI mode
        // the file just reloaded by the template is what we test and restart
        // Xray with, so failing hard here beats silently restarting with a
        // stale config.json. (Raw mode overwrites the file itself and can
        // proceed regardless of the template status.)
        if ($renderStatus === 'ERR' && (string)$mdl->general->config_mode !== 'raw') {
            return ['status' => 'error', 'message' => 'Config regeneration failed: configd template reload returned ERR (see the configd log for the template render error).'];
        }

        // Normalize the template-generated config for readability: the Jinja
        // template emits leading commas (the only reliable way to join
        // conditional sections), so rewrite the file canonically.
        $this->normalizeConfigFile();

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
                if (!$this->writeSecretFile($configFile, $rawJson)) {
                    return ['status' => 'error', 'message' => 'Failed to write Xray config'];
                }
            }
        }

        // Validate the (re)generated config before (re)starting.
        if ((string)$mdl->general->enabled === '1') {
            $testOut = $backend->configdRun('xrayclient test_config');
            $testData = json_decode(trim($testOut), true);
            if (is_array($testData) && ($testData['status'] ?? '') !== 'ok') {
                $testMsg = $testData['message'] ?? 'Xray config test failed';
                // Put the previous config back: otherwise the broken file stays
                // on disk and the next (re)start, including the automatic
                // restart by daemon -r, would run with it.
                $restored = $this->restoreConfig($configFile, $previousConfig);
                return [
                    'status' => 'error',
                    'message' => 'Config test failed: ' . $testMsg
                        . ($restored
                            ? ' — service NOT restarted, previous config restored.'
                            : ' — service NOT restarted; the previous config could not be restored, '
                                . 'fix or reset the config before starting the service.')
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
     * Write a file atomically (temp file + rename) without it ever being
     * readable by other users: config.json holds UUIDs and WireGuard private
     * keys, and a plain file_put_contents() would create the temp file with
     * the default 0644 before the chmod. Returns false on failure.
     */
    private function writeSecretFile($file, $content)
    {
        $tmp = $file . '.tmp';
        $oldUmask = umask(0137);
        $written = file_put_contents($tmp, $content) !== false;
        umask($oldUmask);
        if (!$written || !chmod($tmp, 0640) || !rename($tmp, $file)) {
            @unlink($tmp);
            return false;
        }
        return true;
    }

    /**
     * Copy a config file to a timestamped backup that is only readable by
     * its owner. Returns the backup path, or false on failure.
     */
    private function backupSecretFile($file)
    {
        $backup = $file . '.bak-' . date('Ymd-His');
        $oldUmask = umask(0177);
        $copied = @copy($file, $backup);
        umask($oldUmask);
        if (!$copied) {
            @unlink($backup);
            return false;
        }
        @chmod($backup, 0600);
        $this->pruneBackups($file, 5);
        return $backup;
    }

    /**
     * Keep only the newest $keep backups of a file. Backups carry private
     * keys, so they must not pile up indefinitely.
     */
    private function pruneBackups($file, $keep)
    {
        // The timestamp suffix sorts chronologically.
        $backups = glob($file . '.bak-*') ?: [];
        sort($backups);
        foreach (array_slice($backups, 0, max(0, count($backups) - $keep)) as $old) {
            @unlink($old);
        }
    }

    /**
     * Restore config.json from a backup file created by backupSecretFile().
     */
    private function restoreFromBackup($backup, $file)
    {
        $content = @file_get_contents($backup);
        return $content !== false && $this->writeSecretFile($file, $content);
    }

    /**
     * Put a config snapshot back after a failed validation.
     * Returns false when there was nothing to restore or the write failed.
     */
    private function restoreConfig($file, $previousConfig)
    {
        if ($previousConfig === false) {
            return false;
        }
        return $this->writeSecretFile($file, $previousConfig);
    }

    /**
     * Rewrite the on-disk config canonically (template output uses leading
     * commas). No-op when the file cannot be read or is not valid JSON; the
     * Xray config test afterwards remains the safety net.
     */
    private function normalizeConfigFile()
    {
        $file = '/usr/local/etc/xray/config.json';
        $content = @file_get_contents($file);
        if ($content === false) {
            return;
        }
        // stdClass roundtrip preserves the {} vs [] distinction (empty
        // objects like "stats": {} stay objects; empty lists stay arrays).
        $decoded = json_decode($content);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return;
        }
        $normalized = json_encode($decoded, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if ($normalized === false) {
            return;
        }
        $this->writeSecretFile($file, $normalized);
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
        // The on-disk file is generated by the Jinja template, which puts
        // commas at the start of continuation lines (unavoidable with
        // conditional sections). For display purposes, re-encode canonically
        // (trailing commas, 2-space indent) without touching the file.
        // Decode into stdClass, NOT assoc array: empty objects like
        // "stats": {} must not collapse into [].
        $decoded = json_decode($content);
        if (json_last_error() === JSON_ERROR_NONE) {
            $content = json_encode($decoded, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
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
        @mkdir(dirname($file), 0755, true);

        // Back up the current config before overwriting it.
        $backup = null;
        if (file_exists($file)) {
            $backup = $this->backupSecretFile($file);
            if ($backup === false) {
                return ['status' => 'error', 'message' => 'Failed to back up existing config.json'];
            }
        }
        if (!$this->writeSecretFile($file, $content)) {
            return ['status' => 'error', 'message' => 'Failed to write ' . $file];
        }

        // Validate the written config with Xray itself.
        $backend = new Backend();
        $testOut = $backend->configdRun('xrayclient test_config');
        $testData = json_decode(trim($testOut), true);
        $testOk = is_array($testData) && (($testData['status'] ?? '') === 'ok');
        if (!$testOk) {
            // Roll back to the previous configuration.
            if ($backup !== null) {
                $this->restoreFromBackup($backup, $file);
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

    /**
     * Reset the generated config to the pristine template output: back up the
     * current config.json, switch the plugin back to UI (template) mode,
     * re-render via configd's template handler, normalize, validate with
     * `xray run -test` and restart Xray. On test failure the backup is
     * restored. raw_json and all nodes/rules are left untouched.
     */
    public function resetTemplateAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => 'POST required'];
        }

        $file = '/usr/local/etc/xray/config.json';
        $backup = null;
        if (file_exists($file)) {
            $backup = $this->backupSecretFile($file);
            if ($backup === false) {
                return ['status' => 'error', 'message' => 'Failed to back up current config.json'];
            }
        }

        $mdl = new XrayClient();
        $mdl->general->config_mode = 'ui';
        try {
            $mdl->serializeToConfig();
            \OPNsense\Core\Config::getInstance()->save();
        } catch (\Throwable $e) {
            return [
                'status' => 'error',
                'message' => 'Failed to switch to template mode: ' . preg_replace('/\s+/', ' ', $e->getMessage())
            ];
        }

        $backend = new Backend();
        $renderStatus = trim((string)$backend->configdRun('template reload OPNsense/XrayClient'));
        if ($renderStatus === 'ERR') {
            return ['status' => 'error', 'message' => 'Template render failed (configd returned ERR); the current config.json was left untouched. See the configd log for the template render error.'];
        }
        $this->normalizeConfigFile();

        $testOut = $backend->configdRun('xrayclient test_config');
        $testData = json_decode(trim($testOut), true);
        $testOk = is_array($testData) && (($testData['status'] ?? '') === 'ok');
        if (!$testOk) {
            // Roll back to the previous configuration (and keep template mode).
            if ($backup !== null) {
                $this->restoreFromBackup($backup, $file);
            }
            $message = is_array($testData) ? ($testData['message'] ?? 'Xray config test failed') : trim($testOut);
            return [
                'status' => 'error',
                'message' => 'Template config test failed: ' . $message . ' — previous config restored.'
            ];
        }

        if ((string)$mdl->general->enabled === '1') {
            $backend->configdRun('xrayclient restart');
        } else {
            $backend->configdRun('xrayclient stop');
        }

        return [
            'status' => 'ok',
            'message' => 'Config regenerated from template'
                . ($backup !== null ? ' (previous backed up as ' . basename($backup) . ')' : '')
        ];
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
            'plugin_version' => 'unknown'
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
