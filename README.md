# os-xray-client for OPNsense 26.x

Full-featured Xray-core client plugin for OPNsense with native `tun` interface support, `vless://` / `trojan://` / `ss://` link parser, routing rules editor, latency/traffic monitoring, GeoIP/GeoSite updater, and GitHub self-update.

## Requirements

- OPNsense 26.1 (amd64 or aarch64)
- Root shell access on the firewall
- The installer downloads Xray-core + GeoData from GitHub on first install

## Quick Install on OPNsense

Run the following command in the OPNsense root shell:

```sh
fetch -o /tmp/main.tar.gz https://github.com/tribalRu/os-xray-client/archive/refs/heads/main.tar.gz && tar -xzf /tmp/main.tar.gz -C /tmp && sh /tmp/os-xray-client-main/install.sh
```

Then open **Services > Xray Client**, configure nodes/rules under **General**, and click **Apply & Restart Xray**.

## TUN (`Variant A`) — assigning the interface

1. In **General > TUN Interface Settings**, enable *Enable Native TUN Inbound* (default `tun_xray0`, `10.255.0.1/30`).
2. Click **Apply & Restart Xray** — `setup_tun.sh` creates the interface and `xray` creates its own `tun-in` inbound on the same name.
3. Add a gateway and LAN→wan firewall rule that points traffic to the TUN gateway, then assign under **Interfaces > Assignments** if needed.
4. To use domain rules (`geosite:ru`, …) leave *Enable Domain Sniffing* on.

The prestart script honours `enable_tun`: with TUN disabled no interface is created.

## Notes

- **Raw JSON mode**: paste a complete Xray config into *Raw Xray JSON*; it's validated (`json_decode`) and tested (`xray run -test`) before restart. In UI mode the template escapes all string values (`tojson`), so quotes in names/addresses won't break `config.json`.
- **Latency/Traffic**: *Check Latency* is a bare TCP connect to each enabled node's address:port (not a full VLESS/REALITY handshake). Traffic counters come from Xray's StatsService (`127.0.0.1:10085`).
- **GeoData presets**: `official` (Loyalsoldier), `runetfreedom` (RU), `zaborona` (Iran-specific, Chocolate4U), `custom` (your `.dat` URLs).
- **Self-update**: *Maintenance* can update Xray-core, GeoData, or the plugin itself. Plugin self-update only accepts `https://github.com/owner/repo` URLs and a safe branch name.

## Uninstall

```sh
sh /tmp/os-xray-client-main/uninstall.sh
```

This removes the plugin files. The Xray binary, GeoData and `/usr/local/etc/xray/config.json` are kept for a future reinstall — remove them manually if you want a fully clean box.

## Development / Git

Files are LF-only (see `.gitattributes`). On Windows, keep `git config core.fileMode false` so the executable bits (`755`) of scripts aren't lost; `install.sh` also re-applies `chmod +x` on the firewall.

## License

GPL-3.0
