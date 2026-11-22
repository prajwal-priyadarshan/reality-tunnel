# reality-tunnel

Your own private tunnel on **Azure**, for networks (college or office Wi-Fi) that block
sites and commercial VPNs. One script creates the server. Your Mac connects with
[sing-box](https://sing-box.sagernet.org/).

- **Hard to detect:** VLESS + Reality on port 443. To the firewall it looks like a
  normal HTTPS visit to `www.microsoft.com`.
- **Your own IP in your chosen region** (for example India), used only by you. Useful
  for brokers such as Zerodha, which check login IPs.
- **Split routing:** unblocked heavy sites (Google, YouTube…) skip the tunnel for speed,
  and sites that refuse cloud IPs (HDFC Securities) go direct with a split TLS handshake.
- **No SSH:** only TCP 443 is open. You manage the server from the Azure portal.

> **Before you start:** running your own VPN is legal in India, but it may break your
> institution's IT acceptable-use policy. That's your call. Don't share your link, and
> don't use it to harm anyone.

---

## Getting access
This repo is **private**. Ask the owner to add your GitHub account
(Settings → Collaborators → Add people). To clone it in Azure Cloud Shell, sign in to
GitHub there first with `gh auth login` (already installed in Cloud Shell), then use the
`git clone` commands below.

## What you need
- An Azure subscription. **Azure for Students** works with no credit card:
  sign up at https://azure.microsoft.com/en-in/free/students/ with your college email.
- A Mac with [Homebrew](https://brew.sh).
- About 15 minutes.

## Cost
`deploy.sh` shows live prices before it creates anything. Central India, Nov 2026:

| Size | Approx. per month |
|---|---|
| Standard_B1s (often free for students for 12 months, but often out of capacity) | $4–15 |
| Standard_B2ats_v2 | ~$11 |

That's the VM, plus about $3.65 for a static IP and about $2.64 for a 30 GB disk. The
first 100 GB/month of data is free. With student credit there's no card on file, so
you can't be billed beyond the credit.

---

## Step 1: Check your network (optional, 1 min)
On the restricted Wi-Fi, without any VPN:
```bash
git clone https://github.com/prajwal-priyadarshan/reality-tunnel.git && cd reality-tunnel
bash client/diagnose.sh
```
"handshake reset → SNI filter" with only ports 80/443 open is exactly what this tunnel
gets around.

## Step 2: Create the server (Azure Cloud Shell, 5 min)
1. Go to https://shell.azure.com and choose **Bash**. If asked, pick
   **No storage account required** and your subscription.
2. Run:
   ```bash
   git clone https://github.com/prajwal-priyadarshan/reality-tunnel.git && cd reality-tunnel
   bash azure/deploy.sh
   ```
   Other region? `LOCATION=southindia bash azure/deploy.sh`.
   The script checks your subscription's allowed regions first.
3. Type `y` after checking the prices. The script:
   - registers the Compute and Network services (one-time)
   - creates resource group `reality-vpn-rg` and a small Ubuntu 24.04 VM, trying sizes
     in order until one has capacity
   - opens **only port 443**
   - on first boot, installs sing-box and generates **fresh keys on the server**
   - prints your `vless://...` link
4. **Copy the link.** It's like a password, and Cloud Shell sessions are temporary.
   Lost it? Run this in Cloud Shell:
   ```bash
   az vm run-command invoke -g reality-vpn-rg -n reality-vpn --command-id RunShellScript \
     --scripts 'cat /root/vless_link.txt' --query 'value[0].message' -o tsv
   ```

## Step 3: Set up your Mac (3 min)
```bash
brew install sing-box
cd reality-tunnel
python3 client/make_client_config.py 'vless://...paste your link...'
```
This writes `client/out/` (git-ignored): your link plus two configs.

## Step 4: Connect
**Proxy mode** (browsers; no password):
```bash
bash client/connect.sh
```
**Whole-Mac mode** (every app, including Chrome when it ignores the proxy; needs your Mac password):
```bash
bash client/connect.sh tun
```
Keep the window open and press **Ctrl+C** to disconnect. Check it in a second tab:
```bash
bash client/test.sh        # or: bash client/test.sh tun
```
You should see your server's region and `code=200` for each site.

**Phone:** install **Hiddify** (iOS/Android) and import the same `vless://` link.

---

## Tuning (`client/make_client_config.py`)
| List | Meaning | When to add a site |
|---|---|---|
| `DIRECT` | Goes direct on ports 80/443, skipping the tunnel (faster) | It loads fine on your network without the tunnel (`diagnose.sh` says OK) |
| `DIRECT_FRAGMENT` | Goes direct with a split TLS handshake | It shows 403 "Request blocked" through the tunnel (it blocks cloud IPs) **and** is SNI-blocked on your network |
| everything else | Through your server | — |

After editing, regenerate the configs and restart `connect.sh`:
```bash
python3 client/make_client_config.py "$(cat client/out/vless_link.txt)"
```

Also built in:
- **QUIC (UDP 443) is rejected**, so Chrome falls back to TCP straight away instead of
  waiting on blocked UDP.
- **Tun mode uses MTU 1500 and the "mixed" stack.** macOS's default of 65535 stalled
  parallel downloads.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `deploy.sh`: "Region not allowed" | Use one of the regions it lists: `LOCATION=... bash azure/deploy.sh` |
| All sizes "not available" | Try another region, or `SIZES="Standard_B2s" bash azure/deploy.sh` |
| `ERR_CONNECTION_RESET` in Chrome, proxy mode | Chrome is bypassing the system proxy. Use `connect.sh tun` |
| One site returns 403 through the tunnel | It blocks cloud IPs. Add it to `DIRECT_FRAGMENT` |
| A `DIRECT` site times out | Your network blocks it. Remove it from `DIRECT` |
| Every site fails, log says `reality verification failed` | Client and server keys or versions don't match. Regenerate the configs from the link |
| No internet after a crash in proxy mode | System Settings → Network → Wi-Fi → Details → Proxies → turn them off |
| `connect.sh tun` asks for a password every time | Optional: `echo "$USER ALL=(root) NOPASSWD: $(command -v sing-box)" \| sudo tee /etc/sudoers.d/sing-box` (lets any program running as you start sing-box as root) |

## Stop paying / delete
- **Pause:** Azure portal → Virtual machines → `reality-vpn` → **Stop** (the IP still costs ~$3.65/month).
- **Delete everything:** `bash azure/destroy.sh` in Cloud Shell. This can't be undone.

## Repo layout
```
azure/deploy.sh          create the server (Cloud Shell)
azure/destroy.sh         delete everything
server/cloud-init.sh     first-boot setup on the VM (sing-box + fresh keys)
client/diagnose.sh       how your network blocks things
client/make_client_config.py  link -> sing-box configs (routing rules live here)
client/connect.sh        start the tunnel (proxy or tun)
client/test.sh           check exit IP and sites
```

## Why sing-box on both ends?
The first version used Xray on the server. Xray 26.x and the sing-box 1.14 client failed
the Reality handshake ("reality verification failed") even with matching keys. Using
sing-box on both ends fixed it.
