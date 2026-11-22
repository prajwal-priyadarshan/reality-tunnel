# Step-by-step setup guide

This guide takes you from nothing to a working tunnel, one click at a time. You need no
credit card and no coding knowledge. It takes about **20 minutes** in all.

**Before you start, have ready:**
- your **college email address** (for Azure for Students)
- a phone that can receive an SMS (Microsoft verifies your number)
- the device you want to use: Mac, Windows PC, Android phone or iPhone

**Contents**
- [Part 1: Get a free Azure for Students account](#part-1-get-a-free-azure-for-students-account) (5 min, one time)
- [Part 2: Open Azure Cloud Shell](#part-2-open-azure-cloud-shell) (2 min)
- [Part 3: Create your server](#part-3-create-your-server) (5 min)
- [Part 4: Save your link](#part-4-save-your-link) (1 min)
- [Part 5: Connect your device](#part-5-connect-your-device) (2 to 5 min)
- [Part 6: Check it works](#part-6-check-it-works)
- [Part 7: Keep an eye on your credit](#part-7-keep-an-eye-on-your-credit)
- [Part 8: Delete everything (when you're done)](#part-8-delete-everything-when-youre-done)
- [If something goes wrong](#if-something-goes-wrong)

> [!IMPORTANT]
> Do Parts 1 to 4 on a network where Azure isn't blocked, such as **mobile data or home
> Wi-Fi**. After that, the tunnel works on college Wi-Fi.

---

## Part 1: Get a free Azure for Students account

You get **USD 100 of credit for 12 months**. This server uses about USD 11 a month, so the
credit lasts the whole year. Skip this part if you already have Azure for Students.

1. Go to **[azure.microsoft.com/free/students](https://azure.microsoft.com/en-in/free/students/)**.
2. Click **Start free**.
3. Sign in with a Microsoft account. If you don't have one, click **Create one** and use any
   email address (a personal Gmail is fine).
4. On the form:
   - **School email address:** type your **college email** (for example `name@college.edu.in`).
   - Fill in your name, country (**India**) and date of birth.
   - Enter your phone number and the SMS code you receive.
5. Microsoft sends a verification email to your **college inbox**. Open it and click the link.
   - If no email arrives within 10 minutes, check spam. Some colleges aren't recognised
     automatically; Azure then offers to verify you with a student ID instead.
6. Accept the agreement and click **Sign up**. You land on the **Azure portal**
   ([portal.azure.com](https://portal.azure.com)).

> [!NOTE]
> You are never charged. When the credit runs out or the 12 months end, everything simply
> stops until you renew (you can renew each year while you're a student).

---

## Part 2: Open Azure Cloud Shell

Cloud Shell is a terminal that runs inside your browser. Azure tools are already installed
in it, so you install nothing on your computer.

1. Go to **[shell.azure.com](https://shell.azure.com)** and sign in with the same account.
2. When asked to choose, click **Bash** (not PowerShell).
3. If you see **"Getting started"**:
   - choose **No storage account required**
   - pick your subscription, **Azure for Students**
   - click **Apply**
4. Wait until you see a prompt like this:
   ```
   yourname@Azure:~$
   ```

**How to paste into Cloud Shell:** `Ctrl+Shift+V` on Windows, `Cmd+V` on Mac, or right-click
→ Paste.

---

## Part 3: Create your server

1. Paste this into Cloud Shell and press **Enter**:
   ```bash
   git clone https://github.com/prajwal-priyadarshan/reality-tunnel.git && cd reality-tunnel
   ```
2. Then paste this and press **Enter**:
   ```bash
   bash azure/deploy.sh
   ```
3. The script shows your subscription and a **price table** with live prices, something like this:
   ```
   ==> Estimated monthly cost in centralindia (730 h, USD)
     Standard_B1s         VM $ 7.59 + IP $3.65 + 30GB disk $2.40 = ~$13.64/month
     Standard_B2ats_v2    VM $ 6.86 + IP $3.65 + 30GB disk $2.40 = ~$12.91/month
     ...
   Create the server now? [y/N]
   ```
   Type **`y`** and press **Enter**.
4. Wait **3 to 6 minutes**. You'll see steps go by:
   ```
   ==> Registering Compute and Network providers
   ==> Creating resource group reality-vpn-rg in centralindia
   ==> Creating VM reality-vpn (Standard_B1s)
      Standard_B1s not available here (SkuNotAvailable). Trying the next size…
   ==> Creating VM reality-vpn (Standard_B2ats_v2)
   ==> Opening TCP 443 only (SSH stays closed)
   ==> Server reality-vpn (Standard_B2ats_v2) is up at 20.x.x.x. Waiting for first-boot setup…
   ```
   A line saying a size is **"not available here"** is normal. The script just tries the next
   size.
5. At the end you see **your link**:
   ```
   Your connection link (treat it like a password):

   vless://1b2c3d4e-....@20.x.x.x:443?security=reality&sni=www.microsoft.com&...
   ```

**What the script did in your Azure account:**

| Created | Why |
|---|---|
| Resource group `reality-vpn-rg` | A folder holding everything below, so it's easy to delete later |
| Ubuntu 24.04 virtual machine `reality-vpn` | Your server, in Pune (Central India) |
| Static public IP | The address your devices connect to |
| 30 GB disk | The server's drive |
| Network rule for port 443 | The only open port. SSH and everything else stay closed |

On first boot, the server installed **sing-box**, made **new private keys** that only your
server knows, and wrote your link.

> [!TIP]
> If the script says your region isn't allowed, it lists the regions you **can** use. Run it
> again with one of them, for example:
> ```bash
> LOCATION=southindia bash azure/deploy.sh
> ```

---

## Part 4: Save your link

Your link is the **one thing** your devices need. Anyone who has it can use your server, so
treat it like a password.

1. Select the whole `vless://…` line in Cloud Shell with your mouse (it's one long line).
2. Copy it: `Ctrl+C` on Windows (or right-click → Copy), `Cmd+C` on Mac.
3. Save it somewhere private, such as your phone's notes app or a message to yourself.

**Lost it, or closed Cloud Shell too early?** Open Cloud Shell again and run:
```bash
az vm run-command invoke -g reality-vpn-rg -n reality-vpn --command-id RunShellScript --scripts 'cat /root/vless_link.txt' --query 'value[0].message' -o tsv
```

---

## Part 5: Connect your device

Pick your device. You can use the same link on several devices.

### Android or iPhone (easiest)

1. Install **Hiddify** from the Play Store or App Store (it's free).
2. Copy your `vless://…` link on the phone.
3. Open Hiddify, tap **+** (top right) → **Add from clipboard**.
4. Tap the big **connect** button. Allow the VPN permission when asked.

### Mac

1. Open **Terminal** (press `Cmd+Space`, type *Terminal*, press Enter).
2. If you don't have Homebrew, install it first (it asks for your Mac password):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install sing-box and download this repo:
   ```bash
   brew install sing-box
   ```
   ```bash
   git clone https://github.com/prajwal-priyadarshan/reality-tunnel.git ~/reality-tunnel && cd ~/reality-tunnel
   ```
4. Make your configs. Paste your own link between the single quotes:
   ```bash
   python3 client/make_client_config.py 'vless://…your link…'
   ```
5. Connect:
   ```bash
   bash client/connect.sh tun
   ```
   Enter your Mac password when asked. **Keep this Terminal window open**; closing it, or
   pressing `Ctrl+C`, disconnects.
6. Next time, you only need:
   ```bash
   cd ~/reality-tunnel && bash client/connect.sh tun
   ```

### Windows 10 or 11

The simplest way is an app:

1. Download **Hiddify** for Windows from its GitHub releases page
   ([github.com/hiddify/hiddify-app/releases](https://github.com/hiddify/hiddify-app/releases)),
   file `Hiddify-Windows-Setup-x64.exe`, and install it.
2. Copy your `vless://…` link.
3. Open Hiddify, click **+** → **Add from clipboard**.
4. Click **connect**. If Windows asks for permission, click **Yes**.

The [README's Windows section](README.md#windows) also has a command-line way using
sing-box, with the same routing rules as the Mac.

---

## Part 6: Check it works

With the tunnel on, open these in your browser:

1. **[ipinfo.io](https://ipinfo.io)** should show **Microsoft Corporation** and **Pune**
   (or your server's region). That means your traffic is going through your server.
2. Open the sites that were blocked before (Zerodha Kite, Groww, Instagram and so on). They
   should load.

On Mac you can test several sites at once:
```bash
cd ~/reality-tunnel && bash client/test.sh tun
```

---

## Part 7: Keep an eye on your credit

1. Go to **[portal.azure.com](https://portal.azure.com)**.
2. Search for **Subscriptions** at the top, then click **Azure for Students**.
3. The overview shows your **remaining credit** and the **end date**. You can also search
   the portal for **Education** to see the same numbers.

Expect about **USD 11 a month**, so roughly USD 9 of your USD 100 is used each month.

---

## Part 8: Delete everything (when you're done)

This removes the server, IP and disk, and stops all charges. **It can't be undone**; your
link stops working for good.

1. Open **[shell.azure.com](https://shell.azure.com)** (Bash).
2. Run:
   ```bash
   cd reality-tunnel 2>/dev/null || git clone https://github.com/prajwal-priyadarshan/reality-tunnel.git && cd reality-tunnel
   ```
   ```bash
   bash azure/destroy.sh
   ```
3. It lists what will be deleted. Type **`reality-vpn-rg`** and press **Enter** to confirm.

Want it again later? Just repeat [Part 3](#part-3-create-your-server). You'll get a new link.

---

## If something goes wrong

| What you see | What to do |
|---|---|
| Sign-up says your college isn't recognised | Choose the option to verify with a student ID or document |
| Cloud Shell asks to create storage | Pick **No storage account required** |
| `Region 'centralindia' is not allowed` | Re-run with one of the listed regions: `LOCATION=<region> bash azure/deploy.sh` |
| `None of these sizes had capacity` | Try another allowed region with `LOCATION=...` |
| `Setup did not finish in time` | Wait 5 minutes, then use the command in [Part 4](#part-4-save-your-link) to get your link |
| Hiddify connects but no site loads | Check the link was copied whole (it's long). Delete the profile and add it again |
| Mac: `sing-box: command not found` | Run `brew install sing-box` again |
| Mac: no internet after closing Terminal | Run `bash client/connect.sh tun` again, then press `Ctrl+C` to disconnect cleanly |
| Everything was working, then stopped | In the Azure portal, check the VM `reality-vpn` is **Running**, and that you still have credit |

More fixes are in the [README's Troubleshooting section](README.md#troubleshooting).
