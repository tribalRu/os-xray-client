#!/usr/local/bin/python3
"""
WARP (Cloudflare) WireGuard config generator.

Generates a WireGuard keypair, registers with Cloudflare's WARP API, and
returns a JSON payload with all fields needed to fill the Xray Client
WireGuard node dialog (private key, server public key, endpoint, allowed IPs,
DNS, MTU, reserved bytes).

Usage:
    python3 warp.py

Outputs JSON to stdout. On error, outputs {"status": "error", "message": "..."}.
"""

import base64
import json
import secrets
import socket
import subprocess
import sys
import urllib.error
import urllib.request

# Fail fast on any network operation (DNS, connect, read).
socket.setdefaulttimeout(8)

CONFIG_PATH = '/conf/config.xml'

# Cloudflare WARP registration endpoints (tried in order). The trailing
# version number changes periodically; we fall back to a few known ones.
WARP_REGISTRATION_URLS = [
    "https://api.cloudflareclient.com/v0a2233/reg",
    "https://api.cloudflareclient.com/v0a2214/reg",
]

# WARP fallback values used when the API registration fails or is unreachable.
# These are public WireGuard values published by Cloudflare for WARP.
WARP_FALLBACK_PUBLIC_KEY = "bmXOC+F1FxEMF9dyiK2H5/1SUlzH7xJzvV6PZuLgLVs="
WARP_FALLBACK_ENDPOINT = "162.159.193.10:2408"
WARP_FALLBACK_ALLOWED_IPS = "0.0.0.0/0,::/0"
WARP_FALLBACK_DNS = "1.1.1.1,1.0.0.1"
WARP_FALLBACK_MTU = "1280"


def generate_wg_keypair():
    """Generate a WireGuard keypair. Returns (private_key_b64, public_key_b64)."""
    # Method 1: wg command-line tool (preferred, uses kernel wireguard tools)
    try:
        priv = subprocess.run(
            ["wg", "genkey"],
            capture_output=True, text=True, timeout=10,
        )
        if priv.returncode == 0 and priv.stdout.strip():
            priv_key = priv.stdout.strip()
            pub = subprocess.run(
                ["wg", "pubkey"],
                input=priv_key, capture_output=True, text=True, timeout=10,
            )
            if pub.returncode == 0 and pub.stdout.strip():
                return priv_key, pub.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass

    # Method 2: Python cryptography library (Curve25519)
    try:
        from cryptography.hazmat.primitives.asymmetric.x25519 import (
            X25519PrivateKey,
        )
        priv_key_obj = X25519PrivateKey.generate()
        priv_key_bytes = priv_key_obj.private_bytes_raw()
        pub_key_bytes = priv_key_obj.public_key().public_bytes_raw()
        return (
            base64.b64encode(priv_key_bytes).decode(),
            base64.b64encode(pub_key_bytes).decode(),
        )
    except ImportError:
        pass

    raise RuntimeError(
        "Cannot generate WireGuard keypair: neither 'wg' command-line tool "
        "nor Python 'cryptography' library is available on this system."
    )


def warp_register(public_key_b64):
    """Register with Cloudflare WARP API. Returns parsed JSON response or None."""
    install_id = "".join(secrets.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(22))

    payload = {
        "install_id": install_id,
        "fcm_token": "",
        "referrer": "",
        "warp_enabled": True,
        "type": "ios",
        "locale": "en_US",
        "public_key": public_key_b64,
    }

    last_error = None
    for url in WARP_REGISTRATION_URLS:
        try:
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                url,
                data=data,
                headers={
                    "Content-Type": "application/json; charset=UTF-8",
                    "User-Agent": "okhttp/3.12.1",
                },
                method="POST",
            )
            with urllib.request.urlopen(req) as resp:
                body = resp.read().decode("utf-8")
                return json.loads(body)
        except (urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError) as exc:
            last_error = exc
            continue

    if last_error:
        sys.stderr.write(f"warp.py: WARP registration failed: {last_error}\n")
    return None


def extract_warp_fields(reg_response, client_private_key, client_public_key):
    """Extract WireGuard fields from WARP registration response."""
    config = reg_response.get("config", {})
    interface = config.get("interface", {})
    peers = config.get("peers", [])

    # Client private key (always ours)
    private_key = interface.get("private_key", client_private_key)

    # Server public key from first peer
    server_public_key = ""
    endpoint = WARP_FALLBACK_ENDPOINT
    allowed_ips = WARP_FALLBACK_ALLOWED_IPS

    if peers:
        peer = peers[0]
        server_public_key = peer.get("public_key", "")
        ep = peer.get("endpoint", {})
        if isinstance(ep, dict):
            address = ep.get("address", "")
            port = ep.get("port", 2408)
            if address and port:
                endpoint = f"{address}:{port}"
        allowed_ips = ",".join(peer.get("allowed_ips", [WARP_FALLBACK_ALLOWED_IPS]))

    # MTU
    mtu = str(interface.get("mtu", WARP_FALLBACK_MTU))

    # Addresses (local tunnel addresses)
    addresses = interface.get("addresses", [])
    local_addresses = ",".join(addresses) if addresses else ""

    # DNS - WARP uses 1.1.1.1 / 1.0.0.1 by default
    dns = WARP_FALLBACK_DNS

    # Reserved bytes - three random bytes 0-255
    reserved = ",".join(str(secrets.randbelow(256)) for _ in range(3))

    return {
        "status": "ok",
        "wg_secret_key": private_key,
        "wg_public_key": server_public_key,
        "wg_endpoint": endpoint,
        "wg_address": local_addresses,
        "wg_allowed_ips": allowed_ips,
        "wg_keepalive": "25",
        "wg_mtu": mtu,
        "wg_reserved": reserved,
        "wg_remote_dns": dns,
        "license": reg_response.get("account", {}).get("license", ""),
        "token": reg_response.get("token", ""),
    }


def main():
    try:
        client_private_key, client_public_key = generate_wg_keypair()
    except RuntimeError as exc:
        print(json.dumps({"status": "error", "message": str(exc)}))
        return

    reg_response = warp_register(client_public_key)

    if reg_response:
        result = extract_warp_fields(reg_response, client_private_key, client_public_key)
    else:
        # Fallback: use locally generated keypair with public WARP defaults
        result = {
            "status": "ok",
            "wg_secret_key": client_private_key,
            "wg_public_key": WARP_FALLBACK_PUBLIC_KEY,
            "wg_endpoint": WARP_FALLBACK_ENDPOINT,
            "wg_address": "",
            "wg_allowed_ips": WARP_FALLBACK_ALLOWED_IPS,
            "wg_keepalive": "25",
            "wg_mtu": WARP_FALLBACK_MTU,
            "wg_reserved": ",".join(str(secrets.randbelow(256)) for _ in range(3)),
            "wg_remote_dns": WARP_FALLBACK_DNS,
            "license": "",
            "token": "",
            "warning": "WARP API registration unreachable - using public fallback values. You may need to register separately.",
        }

    print(json.dumps(result))


if __name__ == "__main__":
    main()
