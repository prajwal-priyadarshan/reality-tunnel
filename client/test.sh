#!/usr/bin/env bash
# Check the tunnel while connect.sh is running.
#   bash client/test.sh                 -> through the local proxy (proxy mode)
#   bash client/test.sh tun             -> direct (tun mode already routes everything)
#   SITES="https://a https://b" bash client/test.sh   -> your own list
MODE="${1:-proxy}"
PX=(); [ "$MODE" = "proxy" ] && PX=(-x http://127.0.0.1:2080)
SITES="${SITES:-https://kite.zerodha.com https://groww.in https://www.screener.in https://www.tickertape.in https://www.instagram.com https://investright.hdfcsec.com/login}"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36'

echo "Exit IP for tunnelled sites (should be your server's region):"
curl -s -m 10 "${PX[@]}" https://ipinfo.io/json | grep -E '"(ip|city|country|org)"'
echo
for u in $SITES; do
  printf "%-45s " "$u"
  curl -s -o /dev/null -m 15 "${PX[@]}" -A "$UA" -w "code=%{http_code} t=%{time_total}s\n" "$u" || echo "FAIL"
done
