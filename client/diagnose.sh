#!/usr/bin/env bash
# Run on the restricted network WITHOUT the tunnel, to see how it blocks things.
#   bash client/diagnose.sh                       -> default site list
#   bash client/diagnose.sh example.com other.in  -> your own sites
SITES=("$@"); [ ${#SITES[@]} -eq 0 ] && SITES=(zerodha.com kite.zerodha.com groww.in www.screener.in www.tickertape.in investright.hdfcsec.com www.instagram.com www.google.com www.youtube.com github.com)

echo "== Outgoing ports (to 1.1.1.1) =="
for p in 22 53 80 443 853 8443; do printf "  tcp %-5s " $p; nc -z -G 4 1.1.1.1 $p 2>/dev/null && echo open || echo blocked; done

echo; echo "== Per site: local DNS | outside DNS | HTTPS =="
for h in "${SITES[@]}"; do
  l=$(dig +short +time=3 +tries=1 "$h" | grep -E '^[0-9.]+$' | head -1)
  o=$(dig +short +time=3 +tries=1 @1.1.1.1 "$h" 2>/dev/null | grep -E '^[0-9.]+$' | head -1)
  c=$(curl -s -o /dev/null -m 8 --noproxy '*' -w "%{http_code}" "https://$h/" 2>/dev/null); rc=$?
  case "$c:$rc" in
    000:35) r="BLOCKED (handshake reset -> SNI filter)";;
    000:28) r="BLOCKED (timeout)";;
    000:*)  r="FAIL (curl exit $rc)";;
    *)      r="OK ($c)";;
  esac
  printf "  %-26s %-16s %-16s %s\n" "$h" "${l:-none}" "${o:-blocked}" "$r"
done

cat <<'EOF'

How to read this:
  * local DNS empty/wrong but outside DNS fine  -> DNS block (browser "secure DNS" may be enough)
  * DNS fine but HTTPS "handshake reset"        -> SNI filtering -> use this tunnel
  * only 80/443 open                            -> the tunnel must use 443 (it does)
  * a site that is OK here can go in DIRECT in client/make_client_config.py (faster)
EOF
