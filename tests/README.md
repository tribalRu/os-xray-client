# Tests

Run from the repository root:

```sh
pip install jinja2
python3 src/opnsense/scripts/OPNsense/XrayClient/test_scripts.py   # scripts and config.json template
python3 tests/check_static.py                                      # XML, PHP, Volt JavaScript
(cd tests/ui && npm ci && for t in *.cjs; do node "$t" || exit 1; done)   # jsdom UI tests
```

The same three jobs run in GitHub Actions on every push to `main` and on every pull request (`.github/workflows/ci.yml`). They do not need an OPNsense router; checks that need real FreeBSD (native TUN, packet path) are not covered.
