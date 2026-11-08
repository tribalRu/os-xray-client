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
- **Routing rules**: drag-free reordering with the ↑/↓ buttons in the Actions column (rules renumber automatically to 10/20/30…). Adding from dialog offers built-in presets (bypass LAN/private, bypass RU domains/IPs, block ads); "geosite:ru"-style tags need the matching GeoData preset. In the Target Outbound Action field pick a built-in outbound (`direct`, `block`), a node (`node_<uuid>`, stable across add/remove/reorder) or a **balancer** by its tag. Rules can also match on **Inbound Tags** (`tun-in`/`socks-in`/`http-in`/`api-in`), **Source IPs/Subnets** (`192.168.0.0/16`, `geoip:private`, `!geoip:ru` — only for traffic that reaches Xray with the client address, e.g. TUN; behind NAT everyone looks identical), **Source Ports**, **Auth Users** (SOCKS/HTTP auth users) and an optional **Rule Tag** (used in Xray's stats); empty fields are ignored. The **Routing Policy** section sets `routing.domainStrategy`: `IPIfNonMatch` (default — resolve only domains that matched no rule before IP matching), `IPOnDemand` (resolve only when an IP rule needs it) or `AsIs` (never resolve, cheapest, leaks nothing).
- **Load balancing**: the **Balancers** tab groups nodes by tag prefix (`node_` covers every node) and picks one per connection with `random`, `roundRobin`, `leastPing` or `leastLoad`; a `fallbackTag` (default `direct`) is used when the selector matches nothing or every probe fails. A rule that targets a balancer tag is rendered as `balancerTag` instead of `outboundTag`. `leastPing`/`leastLoad` need the observatory in **General Settings → Load Balancer Observatory** (burst - recommended - or background; URL, interval, sampling, timeout). With two nodes at different latencies `leastPing` follows the faster one and switches when it fails.
- **Built-in DNS**: enable **General Settings → Built-in DNS server** to resolve domains through Xray instead of the system resolver. The **DNS Servers** tab manages the list - address (`https://1.1.1.1/dns-query` for DoH, `https+local://…` for DoH direct, `tcp://host` / plain IP for Do53, `fakedns`), optional port, domain rules this server serves (`geosite:ru`, `domain:ya.ru`, `domain:ru` suffix rule — works without GeoData, `full:example.com`), answer filters (`expectedIPs` / `unexpectedIPs` as CIDRs or `geoip:` tags) and `skipFallback` (never answer other domains). Add/edit starts from a built-in preset (Cloudflare / Google / AdGuard DoH for all domains, Cloudflare DoH direct (`https+local://`), Yandex DoH / plain DNS for `.ru/.рф/.su` with expectedIPs `geoip:ru` and skipFallback, and the system resolver), the same way as the rule dialog. Servers with no domain list answer everything else; Xray's default server is skipped for requests already matched by a tagged server. Hosts, query strategy (Use IP / IPv4 / IPv6), cache, parallel query, system hosts are set on the same screen (**General Settings → Built-in DNS server**); static `hosts` can also be a raw JSON object. DNS requests follow the same routing rules as ordinary traffic, so unmatched traffic still goes `direct`. The built-in DNS takes precedence over the raw `dns` JSON in *Advanced JSON Sections*, which is used only while Built-in DNS is off.
- **Latency/Traffic**: *Check Latency* is a bare TCP connect to each enabled node's address:port (not a full VLESS/REALITY handshake). Traffic counters come from Xray's StatsService (`127.0.0.1:10085`). In **General Settings → Automatic Latency & Traffic Telemetry** you can enable background polling: traffic refreshes at the configured interval (30–3600 s), latency is polled every 5 minutes on a separate hardcoded timer. A "Total traffic" summary (↓/↑ across all nodes) is shown next to the refresh button. The Outbound Nodes table then updates automatically instead of only on button click.
- **GeoData presets**: `official` (Loyalsoldier), `runetfreedom` (RU), `zaborona` (Iran-specific, Chocolate4U), `custom` (your `.dat` URLs).
- **Advanced JSON sections**: *General Settings → Advanced JSON Sections* inserts raw blocks into the generated config - a top-level `dns` object, `routing.balancers` and an `observatory`/`burstObservatory` object. They apply in UI Builder mode only (Raw JSON mode replaces the whole file), empty fields are omitted, JSON syntax is checked in the browser, and `xray run -test` remains the final gate on Apply. These are the fallback path: balancers from the **Balancers** tab take precedence over `balancers_json`, an enabled observatory type overrides `observatory_json`, and Built-in DNS overrides `dns_json`. Balancer `selector` matches outbound tags by prefix, so `"node_"` covers every configured node.
- **Maintenance**: *Maintenance* shows installed Xray-core / GeoData / plugin versions and a **Check for Updates** button that queries GitHub for the latest Xray-core release and the latest plugin commit (it needs outbound HTTPS to github.com). From there you can update Xray-core or the plugin itself in one click; after a plugin update the service is restarted automatically, but only if it was running and the regenerated config passes `xray run -test`.
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
