#!/usr/bin/env bash
# Deploy a VLESS-Reality (sing-box) server on Azure.
# Run in Azure Cloud Shell (Bash), or anywhere `az login` works:
#     bash azure/deploy.sh
# Settings (override with environment variables):
#     LOCATION=centralindia  RG=reality-vpn-rg  NAME=reality-vpn  COVER=www.microsoft.com
#     SIZES="Standard_B1s Standard_B2ats_v2 Standard_B2als_v2 Standard_B1ms"   (tried in order)
set -euo pipefail

LOCATION="${LOCATION:-centralindia}"
RG="${RG:-reality-vpn-rg}"
NAME="${NAME:-reality-vpn}"
COVER="${COVER:-www.microsoft.com}"
SIZES="${SIZES:-Standard_B1s Standard_B2ats_v2 Standard_B2als_v2 Standard_B1ms}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v az >/dev/null || die "Azure CLI not found. Use Azure Cloud Shell (shell.azure.com) or install az."
az account show -o none 2>/dev/null || die "Not signed in. Run: az login"

SUB=$(az account show --query name -o tsv)
say "Subscription: $SUB"

# Student subscriptions often restrict regions with a policy. Check before creating anything.
ALLOWED=$(az policy assignment list --query "[].parameters.listOfAllowedLocations.value[]" -o tsv 2>/dev/null | sort -u | tr '\n' ' ')
if [ -n "$ALLOWED" ] && ! echo " $ALLOWED " | grep -q " $LOCATION "; then
  die "Region '$LOCATION' is not allowed on this subscription. Allowed: $ALLOWED
Re-run with e.g.: LOCATION=<one of those> bash azure/deploy.sh"
fi

# Live prices from the public Azure Retail Prices API (USD, Linux, pay-as-you-go).
price() {  # $1 = filter
  curl -s -G "https://prices.azure.com/api/retail/prices" --data-urlencode "\$filter=$1" |
    python3 -c "import json,sys
items=[i for i in json.load(sys.stdin).get('Items',[]) if i['type']=='Consumption' and 'Spot' not in i['skuName'] and 'Low Priority' not in i['skuName'] and 'Windows' not in i['productName'] and 'Cloud Services' not in i['productName']]
print(min((i['retailPrice'] for i in items), default=0))"
}
say "Estimated monthly cost in $LOCATION (730 h, USD)"
IPH=$(price "serviceName eq 'Virtual Network' and armRegionName eq '$LOCATION' and meterName eq 'Standard IPv4 Static Public IP'")
DISK=$(price "serviceName eq 'Storage' and armRegionName eq '$LOCATION' and skuName eq 'E4 LRS' and meterName eq 'E4 LRS Disk'")
for S in $SIZES; do
  VH=$(price "serviceName eq 'Virtual Machines' and armRegionName eq '$LOCATION' and armSkuName eq '$S' and priceType eq 'Consumption'")
  python3 -c "v,i,d=$VH,$IPH,$DISK; print(f'  {\"$S\":<20} VM \${v*730:5.2f} + IP \${i*730:4.2f} + 30GB disk \${d:4.2f} = ~\${v*730+i*730+d:5.2f}/month')"
done
echo "  (Students: B1s may be free for 12 months under the free-services allowance. Data out: first 100 GB/month free.)"
echo "  The first size that has capacity will be used."
read -r -p $'\nCreate the server now? [y/N] ' OK
[[ "$OK" =~ ^[Yy]$ ]] || die "Cancelled. Nothing was created."

say "Registering Compute and Network providers (one-time, can take a minute)"
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Network --wait

say "Creating resource group $RG in $LOCATION"
az group create -n "$RG" -l "$LOCATION" -o none

sed "s/__COVER__/$COVER/" "$HERE/../server/cloud-init.sh" > "$WORK/cloud-init.sh"

CREATED=""
for SIZE in $SIZES; do
  say "Creating VM $NAME ($SIZE) — 2-4 minutes"
  # --debug output goes to a file: the CLI sometimes crashes while printing deployment
  # errors, so we grep the real error code from the log instead.
  if az vm create -g "$RG" -n "$NAME" -l "$LOCATION" \
      --image Ubuntu2404 --size "$SIZE" \
      --admin-username azureuser --generate-ssh-keys \
      --public-ip-sku Standard --nsg-rule NONE \
      --os-disk-size-gb 30 --storage-sku StandardSSD_LRS \
      --custom-data "$WORK/cloud-init.sh" \
      -o none --debug > "$WORK/create.log" 2>&1; then
    CREATED="$SIZE"; break
  fi
  CODE=$(grep -oE 'SkuNotAvailable|QuotaExceeded|NotAvailableForSubscription|RequestDisallowedByPolicy|OperationNotAllowed|InvalidTemplateDeployment' "$WORK/create.log" | head -1 || true)
  case "$CODE" in
    SkuNotAvailable|QuotaExceeded|NotAvailableForSubscription|OperationNotAllowed)
      echo "   $SIZE not available here ($CODE). Trying the next size…" ;;
    *)
      grep -oE '"message": ?"[^"]{0,300}' "$WORK/create.log" | sort -u | head -5
      die "VM creation failed (${CODE:-unknown error}). Nothing else was changed; delete with: bash azure/destroy.sh" ;;
  esac
done
[ -n "$CREATED" ] || die "None of these sizes had capacity in $LOCATION: $SIZES. Try another LOCATION or SIZES."

say "Opening TCP 443 only (SSH stays closed)"
az vm open-port -g "$RG" -n "$NAME" --port 443 --priority 100 -o none

IP=$(az vm show -d -g "$RG" -n "$NAME" --query publicIps -o tsv)
say "Server $NAME ($CREATED) is up at $IP. Waiting for first-boot setup…"

LINK=""
for i in $(seq 1 12); do
  OUT=$(az vm run-command invoke -g "$RG" -n "$NAME" --command-id RunShellScript \
        --scripts 'grep -hE "SETUP_(DONE|FAILED)" /var/log/reality-setup.log 2>/dev/null; cat /root/vless_link.txt 2>/dev/null' \
        --query 'value[0].message' -o tsv 2>/dev/null || true)
  if echo "$OUT" | grep -q "SETUP_FAILED"; then echo "$OUT"; die "Server setup failed. See /var/log/reality-setup.log on the VM (Run command in the portal)."; fi
  LINK=$(echo "$OUT" | grep -oE 'vless://[^[:space:]]+' | head -1 || true)
  [ -n "$LINK" ] && break
  echo "   still installing… ($i/12)"; sleep 15
done
[ -n "$LINK" ] || die "Setup did not finish in time. Re-run just the last step later:
az vm run-command invoke -g $RG -n $NAME --command-id RunShellScript --scripts 'cat /root/vless_link.txt' --query 'value[0].message' -o tsv"

cat <<EOF

================================ DONE ================================
Server: $NAME  size: $CREATED  region: $LOCATION  IP: $IP

Your connection link (treat it like a password):

$LINK

Copy it now — Cloud Shell sessions are temporary.
Next, on your Mac:  python3 client/make_client_config.py '<link>'
Delete everything later with:  bash azure/destroy.sh
======================================================================
EOF
