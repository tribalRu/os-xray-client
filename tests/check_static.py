#!/usr/bin/env python3
"""Static checks that need no router: every XML file is well-formed, the Volt
view has valid JavaScript, and PHP files pass `php -l` (when php is present)."""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import xml.dom.minidom

ROOT = pathlib.Path(__file__).resolve().parent.parent
errors = []

for path in sorted((ROOT / 'src').rglob('*.xml')):
    try:
        xml.dom.minidom.parse(str(path))
    except Exception as exc:
        errors.append('XML %s: %s' % (path.relative_to(ROOT), exc))

volt = ROOT / 'src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt'
text = volt.read_text(encoding='utf-8')
code = '\n'.join(re.findall(r'<script>(.*?)</script>', text, flags=re.S))
code = re.sub(r'\{\{.*?\}\}', '0', code, flags=re.S)
code = re.sub(r'\{%.*?%\}', '', code, flags=re.S)
with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as handle:
    handle.write(code)
node = shutil.which('node')
if node:
    res = subprocess.run([node, '--check', handle.name], capture_output=True, text=True)
    if res.returncode != 0:
        errors.append('index.volt JavaScript: ' + res.stderr[:600])

php = shutil.which('php')
if php:
    for path in sorted((ROOT / 'src').rglob('*.php')) + sorted((ROOT / 'src').rglob('*.inc')):
        res = subprocess.run([php, '-l', str(path)], capture_output=True, text=True)
        if res.returncode != 0:
            errors.append('PHP %s: %s' % (path.relative_to(ROOT), res.stdout.strip() or res.stderr.strip()))

for line in errors:
    print('ERROR', line)
print('static checks: %s' % ('FAILED' if errors else 'OK'))
sys.exit(1 if errors else 0)
