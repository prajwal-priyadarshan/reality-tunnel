#!/bin/bash
# First-boot script for the VM (passed as Azure custom-data by azure/deploy.sh).
# Installs sing-box, generates fresh keys ON THE SERVER, and writes the client
# link to /root/vless_link.txt. __COVER__ is replaced by deploy.sh.
set -euo pipefail
exec >/var/log/reality-setup.log 2>&1

COVER="__COVER__"
PORT=443

apt-get update -y
apt-get install -y curl openssl

echo "== checking cover site $COVER answers with TLS 1.3"
if ! curl -sv -o /dev/null -m 15 "https://$COVER/" 2>&1 | grep -q "TLSv1.3"; then
  echo "SETUP_FAILED: cover site $COVER is not reachable with TLS 1.3 from this server"
  exit 1
fi

echo "== installing sing-box (official installer)"
curl -fsSL https://sing-box.app/install.sh | sh

UUID=$(sing-box generate uuid)
KP=$(sing-box generate reality-keypair)
PRIV=$(echo "$KP" | awk '/PrivateKey/{print $2}')
PUB=$(echo "$KP" | awk '/PublicKey/{print $2}')
SID=$(openssl rand -hex 8)

mkdir -p /etc/sing-box
umask 077
cat >/etc/sing-box/config.json <<EOF
{
  "log": { "level": "warn" },
  "inbounds": [{
    "type": "vless", "tag": "in", "listen": "::", "listen_port": $PORT,
    "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
    "tls": {
      "enabled": true,
      "server_name": "$COVER",
      "reality": {
        "enabled": true,
        "handshake": { "server": "$COVER", "server_port": 443 },
        "private_key": "$PRIV",
        "short_id": ["$SID"]
      }
    }
  }],
  "outbounds": [{ "type": "direct" }]
}
EOF
sing-box check -c /etc/sing-box/config.json

echo "== BBR congestion control"
grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf || {
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' >> /etc/sysctl.conf
  sysctl -p || true
}

systemctl enable sing-box
systemctl restart sing-box
sleep 1
systemctl is-active --quiet sing-box

IP=$(curl -4 -s -m 10 https://api.ipify.org || hostname -I | awk '{print $1}')
echo "vless://$UUID@$IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$COVER&fp=chrome&pbk=$PUB&sid=$SID&type=tcp#reality-$IP" > /root/vless_link.txt
chmod 600 /root/vless_link.txt
echo "SETUP_DONE"
