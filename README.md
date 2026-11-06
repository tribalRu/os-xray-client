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

## TUN (`Variant A`) — transparent L3 routing

Xray-core **creates the TUN interface itself** while the service runs (FreeBSD `tun(4)`); it does not exist otherwise, and the plugin deliberately never pre-creates it (a pre-created interface makes Xray fail with `interface already exists`).

1. In **General > TUN Interface Settings**, enable *Enable Native TUN Inbound* (default interface `tun_xray0`, gateway prefix `10.255.0.1/30`, MTU `1500`).
   - `TUN Tunnel Subnet` is the **gateway prefix** Xray uses for the tunnel: Xray keeps the gateway address (`10.255.0.1`) as the in-tunnel endpoint and assigns the next address to the interface (`10.255.0.2` for a `/30`). CIDR must be `1..31` so a local address exists inside the prefix.
2. Click **Apply & Restart Xray**. The prestart hook removes a stale interface left by an older plugin version / an unclean Xray crash, then Xray creates `tun_xray0` itself.
3. Assign it under **Interfaces > Assignments**, save, enable it (e.g. `opt5`), and create a gateway pointing at `10.255.0.1` **with gateway monitoring disabled** (the far end has no real host to ping).
4. Add a LAN firewall rule that routes selected (or all) traffic to that gateway (Firewall > Rules > LAN > Advanced > Gateway).
5. To use domain rules (`geosite:ru`, …) keep *Enable Domain Sniffing* on.
6. Traffic is decided per connection by Xray's routing rules (`proxy` / `direct` / `block`); `direct` traffic exits via the normal WAN route.

Full-tunnel auto-routing (`autoSystemRoutingTable`, which replaces the system routing table and binds outbounds to a physical interface via a second FIB) is not wired up yet: on FreeBSD it requires `net.fibs=2` in `/boot/loader.conf` and a reboot. Manual policy routing above works out of the box.

The prestart/poststop hooks honour `enable_tun` and clean up stale interfaces automatically.

## Notes

- **Raw JSON mode**: paste a complete Xray config into *Raw Xray JSON*; it's validated (`json_decode`) and tested (`xray run -test`) before restart. In UI mode the template escapes all string values (`tojson`), so quotes in names/addresses won't break `config.json`.
- **Expert Mode**: General → *Expert Mode* shows an extra **Expert Config** tab with the exact `/usr/local/etc/xray/config.json` Xray runs. View it read-only or edit it manually; saving validates (`xray run -test`), backs up the previous file (`config.json.bak-*`), switches the plugin to Raw JSON mode and restarts Xray. The UI builder no longer regenerates the file until you switch back.
- **Routing rules**: drag-free reordering with the ↑/↓ buttons in the Actions column (rules renumber automatically to 10/20/30…). Adding from dialog offers built-in presets (bypass LAN/private, bypass RU domains/IPs, block ads); "geosite:ru"-style tags need the matching GeoData preset.
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
