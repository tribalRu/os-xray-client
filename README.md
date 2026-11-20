# os-xray-client

**English** · [Русский](README.ru.md)

A plugin that runs **[Xray-core](https://github.com/XTLS/Xray-core)** on **OPNsense 26.x** and manages it from the web UI.
Add your proxy servers, decide which traffic goes where, and the plugin turns that into an Xray config, starts the service and keeps an eye on it. No SSH editing of JSON files required (though you can, if you like).

> **Unofficial plugin.** This is an independent, community project. It is **not** an official OPNsense plugin and is not made, supported or endorsed by the OPNsense project (Deciso), the Xray / XTLS project or Cloudflare. It is not available from the OPNsense plugin repository; it is installed from this repository.

Typical use: a home or office firewall that sends some traffic through a VLESS / Trojan / WireGuard / WARP server and the rest straight to the internet, for example *"Russian sites direct, everything else through the proxy"*.

## What you get

- **Servers (outbound nodes)** — VLESS, VMess, Trojan, Shadowsocks, SOCKS 5, HTTP, WireGuard, Hysteria 2, MASQUE, plus Freedom / Blackhole / DNS / Loopback. Paste a `vless://`, `vmess://`, `trojan://`, `ss://` or `hy2://` link and the form is filled in for you.
- **Routing rules** — a readable rule list, reordered with arrow buttons, *Pin to top* / *Pin to end*, one-click presets (LAN direct, Russia direct, blocked-in-Russia via proxy, block ads, BitTorrent direct, block QUIC, everything else via proxy) and a configurable **Default Action** for traffic nothing else matched.
- **GeoData browser** — look inside `geosite.dat` / `geoip.dat`, search categories and entries, insert them into a rule; typos in `geosite:` / `geoip:` tags are flagged before Apply.
- **Load balancing** — balancers with failover and least-ping / least-load strategies, and a live view of which node is picked.
- **Transparent routing** — Xray creates a native TUN interface; point an OPNsense gateway and a firewall rule at it and whole LAN segments go through the proxy.
- **Local proxies** — optional SOCKS5 and HTTP listeners on the firewall.
- **Built-in DNS** — Xray's own resolver with per-domain servers (for example Russian domains to a Russian resolver).
- **WARP** — one-click Cloudflare WARP (WireGuard or MASQUE).
- **Working-address finder for WARP and WARP MASQUE** — when the default WARP address is blocked, the *Find working endpoint* button searches for addresses and ports that really work from your router (see below).
- **Monitoring** — latency check per node, traffic counters, live rates, a dashboard widget and a log viewer.
- **Maintenance** — update Xray-core, GeoIP/GeoSite and the plugin itself from the UI, with a progress window and error reporting.
- **Safe apply** — the generated config is validated with `xray run -test` before the service is restarted; a broken config rolls back to the previous one.

## Requirements

- OPNsense 26.1 or newer (amd64 or aarch64) and a root shell on it
- Internet access from the firewall to GitHub (Xray-core, GeoData and updates are downloaded from there)

## Install

In the OPNsense root shell:

```sh
fetch -o /tmp/main.tar.gz https://github.com/tribalRu/os-xray-client/archive/refs/heads/main.tar.gz && tar -xzf /tmp/main.tar.gz -C /tmp && sh /tmp/os-xray-client-main/install.sh
```

Then open **VPN → Xray Client**.

**Update:** *Maintenance* tab → *Check for Updates*, then update Xray-core, GeoData or the plugin. The plugin can also be installed from another branch there (for testing; such a branch is marked as unmerged).

**Uninstall:** `sh /tmp/os-xray-client-main/uninstall.sh`. This removes the plugin only; the Xray binary, GeoData and `/usr/local/etc/xray/config.json` stay for a future reinstall.

## Quick start

1. **Add a server.** *Outbound Nodes* → **+** → paste your link (or fill in the form). Several servers are fine; each gets a stable tag.
2. **Pick GeoData.** *Maintenance* → *GeoData Source Preset* (for example *Russia (runetfreedom)*) → **Update GeoIP & GeoSite**.
3. **Set up routing.** *Routing → Rules* → **+** → choose a preset, or build your own rule. For *"Russia direct, the rest through the proxy"* add these presets: *Bypass Russian domains*, *Bypass Russian IP ranges*, *Everything else → proxy* (and pick your server as the target of the last one). Or set the **Default Action** to your server in *Routing → Policy & Sniffing* and list only the exceptions.
4. **Apply.** Click **Apply & Restart Xray**. If Xray rejects the config you get the exact error and the previous config stays in place.
5. **Send traffic into Xray.**
   - *Transparent mode (TUN):* enable *Native TUN Inbound* in *General*, apply, then in OPNsense:
     1. *Interfaces → Assignments*: pick `tun_xray0` in *New interface* (it is listed only while Xray is running), add a description such as `XRAY`, click **+** and **Save**.
     2. *Interfaces → [XRAY]*: tick **Enable** and **Lock** (*Prevent interface removal*), leave *IPv4 Configuration Type* = **None** (Xray puts the address `10.255.0.2/30` on the interface itself), **Save** and **Apply changes**.
     3. *System → Gateways → Configuration → +*: *Interface* `XRAY`, *IP address* `10.255.0.1`, tick **Disable Gateway Monitoring**, leave *Upstream Gateway* unticked, **Save** and **Apply changes**.
     4. *Firewall → Rules → LAN*: a rule for the wanted traffic with *Advanced → Gateway* = the new gateway.

     Keep *Domain Sniffing* on so domain rules work. More detail and troubleshooting: [docs/REFERENCE.md](docs/REFERENCE.md).
   - *Proxy mode:* enable the local SOCKS5 / HTTP listener and point your clients at it.

## How routing works in two minutes

Xray checks the rules **from top to bottom** and uses the first one that matches. The list in the UI shows everything that exists:

```
 (locked)  api-in → api              statistics API, always first
 pinned to top   ...                 your "must win" exceptions
 regular rules   ...                 ordered with the arrows
 pinned to end   ...                 e.g. "everything else → proxy"
 (locked)  any traffic → Default Action   always last (direct unless you change it)
```

- **Conditions inside one rule are combined with AND.** That is why *domain* and *IP* presets are separate rules.
- A rule with no conditions matches everything, so anything below it is never reached. The UI marks such rules with a warning.
- Pins work like floating rules in the OPNsense firewall: a pinned rule keeps its position no matter what sequence number others have.
- `geosite:` / `geoip:` tags need a GeoData set that contains them, otherwise Xray refuses the config. The tag check in the rule dialog and the GeoData browser help with this.

## Finding a working WARP address

Providers that filter Cloudflare often block the default WARP address, or let a connection start and then cut it. In the node dialog of a **WARP (WireGuard)** node or a **MASQUE node in WARP mode**, the **Find working endpoint** button looks for an address and port that work from *your* router:

- **A real test, not a ping.** Every candidate is tried through a temporary Xray with your keys and has to reach the internet through WARP; the result is confirmed with extra requests and a 300 KB download, plus a final request after a short pause. Addresses that answer once and then hang are shown as *cut mid-stream* and cannot be applied.
- **Ranges and ports** come from the community list of WARP endpoints (WireGuard) and the known MASQUE ranges; your own lists can be added, and unusual ranges tried as an option.
- **Filtered nodes and SNI.** Candidates that land on a filtered Cloudflare node (the Moscow node `DME` by default) are skipped, and MASQUE can try other SNI names when the first packets pass and then nothing arrives.
- **Convenient results.** A window shows every checked endpoint with a flag, the Cloudflare data center, speed and delay; *Use* fills the endpoint into the node dialog, *Re-check* repeats the test, and working endpoints are remembered on the router.

Details of every option are in the [reference](docs/REFERENCE.md).

## A tour of the tabs

| Tab | What it is for |
| --- | --- |
| **General Settings** | Enable the service, TUN, local proxies, logging, monitoring, built-in DNS |
| **Outbound Nodes** | Your servers, link import, latency and traffic, live rates |
| **Routing** | *Rules*, *Balancers*, *Policy & Sniffing* (domain strategy, default action) |
| **DNS Servers** | Servers and per-domain DNS rules for the built-in resolver |
| **Maintenance** | Versions, updates of Xray-core / GeoData / the plugin |
| **Expert Config** | (optional) raw JSON sections or the complete raw config instead of the UI builder |

Rarely needed options are hidden behind **Show advanced fields**.

## When something does not work

- **Page loads hang on LAN clients, `access.log` is empty.** The gateway of your policy rule must be the Xray end of the tunnel subnet (`10.255.0.1` by default), not the address OPNsense assigned to the interface (`10.255.0.2`). Fix it under *System → Gateways*, then run `pfctl -F states`.
- **Apply says the config is invalid.** Read the message: usually a `geosite:`/`geoip:` tag missing from the installed GeoData, or a deleted server still used by a rule.
- **A rule does nothing.** Check its position: an enabled rule without conditions above it, or a *Pin to end* rule, may match first.
- **Statistics or live selection are empty.** Do not disable the locked `api-in → api` rule; it is what serves them.

More details and every option are in the [full reference](docs/REFERENCE.md).

## Development

Files use LF line endings (`.gitattributes`). On Windows keep `git config core.fileMode false` so the executable bits of scripts survive; `install.sh` re-applies `chmod +x` on the firewall. Python unit tests: `python3 src/opnsense/scripts/OPNsense/XrayClient/test_scripts.py`.

## License

Copyright (C) 2026 os-xray-client contributors.

This project is free software, released under the **GNU General Public License, version 3** (GPL-3.0). The full text is in the [LICENSE](LICENSE) file. You may use, study, modify and redistribute it under those terms; if you distribute a modified version, it must stay under the GPL-3.0 and come with its source.

The software is provided **as is, without warranty of any kind**, express or implied, including merchantability and fitness for a particular purpose. You run it on your own firewall at your own risk: always keep a configuration backup and check the result before relying on it.

**Files with their own header.** A few PHP files follow the OPNsense convention and carry a BSD 2-Clause header (`Copyright (C) 2026 os-xray-client contributors`). That licence is compatible with the GPL-3.0; those files stay under the terms of their header.

**Third-party software and data.** This repository does not contain them; the installer and the Maintenance tab download them from their own sources, and each stays under its own licence:

| Component | Source | Licence |
| --- | --- | --- |
| Xray-core | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) | MPL-2.0 |
| GeoIP / GeoSite data | Loyalsoldier, runetfreedom, Chocolate4U or your own URLs (see *GeoData Source Preset*) | as published in each repository |
| OPNsense | [opnsense/core](https://github.com/opnsense/core) | BSD 2-Clause |

**Acknowledgements.** The WARP endpoint search borrows ideas, and the list of SNI names that get past filters, from [vernette/warpscout](https://github.com/vernette/warpscout) (MIT): skipping the filtered Moscow node, trying other SNI names, and treating tunnels that get cut after the first packets as not working. No code of that project is included.

**Services and trademarks.** This is an unofficial plugin: the project is independent and is not affiliated with or endorsed by the Xray / XTLS project, the OPNsense project (Deciso) or Cloudflare. Names such as OPNsense, Xray, WireGuard, Cloudflare and WARP belong to their owners. The WARP features use Cloudflare's public client API: you are responsible for following Cloudflare's terms of service. You are also responsible for using proxies and routing features in accordance with the laws that apply to you.
