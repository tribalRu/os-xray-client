# os-xray-client for OPNsense 26.x

Full-featured Xray-core client plugin for OPNsense with native `tun` interface support, `vless://` link parser, routing rules editor, latency/traffic monitoring, GeoIP/GeoSite updater, and GitHub self-update.

## Quick Install on OPNsense

Run the following command in the OPNsense root shell:

```sh
fetch -o /tmp/main.tar.gz https://github.com/tribalRu/os-xray-client/archive/refs/heads/main.tar.gz && tar -xzf /tmp/main.tar.gz -C /tmp && sh /tmp/os-xray-client-main/install.sh
```

## Uninstall

```sh
sh /tmp/os-xray-client-main/uninstall.sh
```
