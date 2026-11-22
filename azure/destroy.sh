#!/usr/bin/env bash
# Delete EVERYTHING deploy.sh created (VM, IP, disk, network) by deleting the resource group.
# This cannot be undone. Usage: bash azure/destroy.sh   (RG=... to override)
set -euo pipefail
RG="${RG:-reality-vpn-rg}"
az group show -n "$RG" -o none 2>/dev/null || { echo "Resource group $RG does not exist. Nothing to delete."; exit 0; }
echo "This permanently deletes resource group '$RG' and everything in it:"
az resource list -g "$RG" --query "[].{type:type, name:name}" -o table
read -r -p $'\nType the group name to confirm: ' ANSWER
[ "$ANSWER" = "$RG" ] || { echo "Cancelled."; exit 1; }
az group delete -n "$RG" --yes --no-wait
echo "Deletion started. It finishes in a few minutes; charges stop once it's gone."
