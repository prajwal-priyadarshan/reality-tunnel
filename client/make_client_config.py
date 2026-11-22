#!/usr/bin/env python3
"""Turn the vless:// link printed by azure/deploy.sh into sing-box configs.

Usage:  python3 client/make_client_config.py 'vless://...'
Also saves the link to client/out/vless_link.txt so you can regenerate later with:
        python3 client/make_client_config.py "$(cat client/out/vless_link.txt)"
Edit DIRECT_FRAGMENT / DIRECT below to tune routing for your network.
Writes (mode 600) into client/out/:
  config-proxy.json  local proxy on 127.0.0.1:2080, sets the macOS system proxy
                     while running (browsers + most apps). No sudo needed.
  config-tun.json    whole-Mac tunnel (all apps, incl. terminal tools). Needs sudo.
Requires sing-box 1.12 or newer.
"""
import json, os, sys
from urllib.parse import urlparse, parse_qs, unquote

# Sites that refuse cloud/datacenter IPs (e.g. HDFC Securities' CloudFront firewall returns
# 403 "Request blocked"). They go DIRECT from your own connection, with the TLS handshake split
# into records so an SNI-filtering firewall can't read the name. Test with client/diagnose.sh.
DIRECT_FRAGMENT = ["hdfcsec.com"]

# Heavy sites your network does NOT block: skip the tunnel for speed (web ports only).
# This list was tested on one Indian college network; run client/diagnose.sh on yours and
# remove anything that fails directly. Everything not listed goes through your server.
DIRECT = [
    "google.com", "youtube.com", "ytimg.com", "googlevideo.com", "gstatic.com",
    "googleapis.com", "googleusercontent.com", "ggpht.com",
    "github.com",  # not githubusercontent.com: it was partly blocked on the test network
    "microsoft.com", "microsoftonline.com", "live.com", "office.com",
    "icloud.com", "whatsapp.com", "whatsapp.net",
    "claude.ai", "anthropic.com", "wikipedia.org", "stackoverflow.com",
    "linkedin.com", "amazon.in", "flipkart.com",
]


def parse(link):
    u = urlparse(link.strip())
    if u.scheme != "vless":
        sys.exit("Not a vless:// link")
    q = {k: v[0] for k, v in parse_qs(u.query).items()}
    need = ["pbk", "sid", "sni"]
    missing = [k for k in need if not q.get(k)]
    if missing or not u.username or not u.hostname:
        sys.exit(f"Link is missing fields: {missing or 'uuid/host'}")
    if q.get("security") != "reality":
        sys.exit("Link is not a Reality link (security=reality expected)")
    return {
        "uuid": unquote(u.username),
        "server": u.hostname,
        "port": u.port or 443,
        "flow": q.get("flow", "xtls-rprx-vision"),
        "sni": q["sni"],
        "fp": q.get("fp", "chrome"),
        "pbk": q["pbk"],
        "sid": q["sid"],
    }


def outbound(p):
    return {
        "type": "vless",
        "tag": "proxy",
        "server": p["server"],
        "server_port": p["port"],
        "uuid": p["uuid"],
        "flow": p["flow"],
        "tls": {
            "enabled": True,
            "server_name": p["sni"],
            "utls": {"enabled": True, "fingerprint": p["fp"]},
            "reality": {"enabled": True, "public_key": p["pbk"], "short_id": p["sid"]},
        },
    }


def base(p):
    return {
        "log": {"level": "warn", "timestamp": True},
        "outbounds": [outbound(p), {"type": "direct", "tag": "direct"}],
        "route": {
            "rules": [
                {"action": "sniff"},
                {"ip_is_private": True, "outbound": "direct"},
                # Block QUIC (HTTP/3 over UDP 443): college Wi-Fi drops UDP, so Chrome
                # would wait on it before falling back. Rejecting makes it use TCP at once.
                {"network": "udp", "port": 443, "action": "reject"},
                # Sites that block cloud-server IPs: go direct (your real ISP IP),
                # with the TLS handshake split so the college firewall can't read the name.
                {"domain_suffix": DIRECT_FRAGMENT, "action": "route",
                 "outbound": "direct", "tls_record_fragment": True},
                # Only web ports go direct; college Wi-Fi refuses others (e.g. Google push on 5228).
                {"domain_suffix": DIRECT, "port": [80, 443], "outbound": "direct"},
            ],
            "final": "proxy",
            "auto_detect_interface": True,
            "default_domain_resolver": "local",
        },
        "dns": {
            "servers": [
                {"type": "https", "tag": "remote", "server": "8.8.8.8", "detour": "proxy"},
                {"type": "local", "tag": "local"},
            ],
            "final": "remote",
            "strategy": "ipv4_only",
        },
    }


def proxy_cfg(p):
    c = base(p)
    c["inbounds"] = [{
        "type": "mixed", "tag": "mixed-in",
        "listen": "127.0.0.1", "listen_port": 2080,
        "set_system_proxy": True,
    }]
    return c


def tun_cfg(p):
    c = base(p)
    c["inbounds"] = [{
        "type": "tun", "tag": "tun-in",
        "address": ["172.19.0.1/30"],
        # macOS gave the tun interface MTU 65535, and parallel downloads stalled.
        # A normal 1500 MTU and the "mixed" stack fix that.
        "mtu": 1500,
        "auto_route": True, "strict_route": True, "stack": "mixed",
    }]
    c["route"]["rules"].insert(1, {"protocol": "dns", "action": "hijack-dns"})
    return c


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    p = parse(sys.argv[1])
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
    os.makedirs(out, mode=0o700, exist_ok=True)
    files = (("config-proxy.json", json.dumps(proxy_cfg(p), indent=2)),
             ("config-tun.json", json.dumps(tun_cfg(p), indent=2)),
             ("vless_link.txt", sys.argv[1].strip() + "\n"))
    for name, text in files:
        path = os.path.join(out, name)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(text)
        print("wrote", path)
    print(f"server {p['server']}:{p['port']}  cover site {p['sni']}")


if __name__ == "__main__":
    main()
