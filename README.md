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
6. Traffic is decided per connection by Xray's routing rules (`node_<uuid>` / `direct` / `block`); `direct` traffic exits via the normal WAN route.

Full-tunnel auto-routing (`autoSystemRoutingTable`, which replaces the system routing table and binds outbounds to a physical interface via a second FIB) is not wired up yet: on FreeBSD it requires `net.fibs=2` in `/boot/loader.conf` and a reboot. Manual policy routing above works out of the box.

The prestart/poststop hooks honour `enable_tun` and clean up stale interfaces automatically.

### Troubleshooting: pages on LAN clients never leave SYN_SENT, Xray sees nothing (empty access.log)

If the wall/client can ping `192.168.1.199` but cannot open any website, and `netstat -i -I tun_xray0` shows `Ipkts: 0` while pf shows the rule passing packets (`pfctl -sr -v | grep route-to` → non-zero `Packets`), the gateway for the policy rule is pointing at the wrong end of the tunnel.

The gateway must be the **Xray end** of the `/30` (`10.255.0.1` for the default prefix), **not** the address assigned to `opt1` by OPNsense (`10.255.0.2`). Pointing the gateway at `10.255.0.2` makes pf try to route into the wall’s own interface address and silently drop every packet — no error message is produced anywhere and Xray never sees a single packet.

Fix: System → Gateways → Configuration → edit the `XRAY_GW` → *Gateway address* = `10.255.0.1` → Apply → `pfctl -F states` to drop stale SYN_SENT states.

## Outbound protocols

The node dialog supports every outbound protocol implemented by Xray-core. Choosing a protocol shows only its relevant fields:

| Protocol | Authentication / key fields | Transport |
| --- | --- | --- |
| VLESS | UUID, encryption, XTLS flow | RAW, WS, gRPC, XHTTP, HTTPUpgrade + TLS/REALITY |
| VMess | UUID, encryption (`auto`/AES/ChaCha20), experiments | same |
| Trojan | password | same |
| Shadowsocks | cipher + password (2022 keys must be base64) | same |
| SOCKS 5 | username / password (optional) | same |
| HTTP | username / password, extra headers | same |
| WireGuard | private/public keys, PSK, endpoint, allowed IPs, MTU, reserved bytes, remote DNS | native UDP tunnel |
| Hysteria 2 | auth password, UDP idle timeout | QUIC + mandatory TLS |
| MASQUE | username / password, authority, path, headers, remote DNS | HTTP/2 or HTTP/3 + mandatory TLS |
| Freedom | redirect, PROXY protocol, final rules | none |
| Blackhole | response (`none` or HTTP 403) | none |
| DNS | transport/address/port rewrite, rule list | none |
| Loopback | inbound tag used when re-entering routing | none |

Protocol-specific fields, the Transport section, Mux.Cool and the custom `streamSettings` override are shown/hidden dynamically. All generated configs are accepted by `xray run -test` (checked against Xray-core 26.10.31).

## Notes

- **Raw JSON mode**: paste a complete Xray config into *Raw Xray JSON*; it's validated (`json_decode`) and tested (`xray run -test`) before restart. In UI mode the template escapes all string values (`tojson`), so quotes in names/addresses won't break `config.json`.
- **Expert Mode**: General → *Expert Mode* shows an extra **Expert Config** tab with the exact `/usr/local/etc/xray/config.json` Xray runs. View it read-only or edit it manually; saving validates (`xray run -test`), backs up the previous file (`config.json.bak-*`), switches the plugin to Raw JSON mode and restarts Xray. The UI builder no longer regenerates the file until you switch back.
- **Routing rules**: drag-free reordering with the ↑/↓ buttons in the Actions column (rules renumber automatically to 10/20/30…). Adding from dialog offers built-in presets (bypass LAN/private, bypass RU domains/IPs, block ads); "geosite:ru"-style tags need the matching GeoData preset. In the Target Outbound Action field pick one of the built-in outbounds (`direct`, `block`) or a `node_<uuid>` tag naming the node to route traffic through (stable across add/remove/reorder). Unmatched traffic goes `direct`.
- **Latency/Traffic**: *Check Latency* is a bare TCP connect to each enabled node's address:port (not a full VLESS/REALITY handshake). Traffic counters come from Xray's StatsService (`127.0.0.1:10085`). In **General Settings → Automatic Latency & Traffic Telemetry** you can enable background polling: traffic refreshes at the configured interval (30–3600 s), latency is polled every 5 minutes on a separate hardcoded timer. A "Total traffic" summary (↓/↑ across all nodes) is shown next to the refresh button. The Outbound Nodes table then updates automatically instead of only on button click.
- **GeoData presets**: `official` (Loyalsoldier), `runetfreedom` (RU), `zaborona` (Iran-specific, Chocolate4U), `custom` (your `.dat` URLs).
- **Maintenance**: *Maintenance* shows installed Xray-core / GeoData / plugin versions and a **Check for Updates** button that queries GitHub for the latest Xray-core release and the latest plugin commit (it needs outbound HTTPS to github.com). From there you can update Xray-core or the plugin itself in one click.
- **Input validation**: node fields that are critical for Xray are validated on save — WireGuard keys (44 base64 chars), endpoints (`host:port`), SNI/host/path formats, JSON fields (`http_headers`, `custom_stream_json`, `freedom_final_rules`, `dns_rules_json`), CIDR lists and MTU/keepalive/timeouts. Invalid values are rejected with a message before the config is written; `xray run -test` is still the final gate on Apply & Restart.
- **WARP (Cloudflare)**: in the WireGuard section of the Add/Edit node dialog, click **Generate WARP config** to create a local WireGuard keypair, register with Cloudflare's WARP API, and auto-fill all WireGuard fields (private key, server public key, endpoint, allowed IPs, DNS, MTU, keepalive, reserved bytes). Requires outbound HTTPS to `api.cloudflareclient.com`. If registration is unreachable, public WARP fallback values are used instead — you may still need to register via the WARP app/website for a working connection. API version and fallback values can be overridden via optional `/usr/local/etc/xray/warp.json` (must be a JSON object with keys like `api_version`, `registration_urls`, `fallback_public_key`, `fallback_endpoint`, `fallback_allowed_ips`, `fallback_dns`, `fallback_mtu`).

## Uninstall

```sh
sh /tmp/os-xray-client-main/uninstall.sh
```

This removes the plugin files. The Xray binary, GeoData and `/usr/local/etc/xray/config.json` are kept for a future reinstall — remove them manually if you want a fully clean box.

## Development / Git

Files are LF-only (see `.gitattributes`). On Windows, keep `git config core.fileMode false` so the executable bits (`755`) of scripts aren't lost; `install.sh` also re-applies `chmod +x` on the firewall.

## License

GPL-3.0
