# 🚀 OpenVPN Server on GitHub Actions via Cloudflare Tunnel

Run an ephemeral, high-speed **OpenVPN Server** directly inside **GitHub Actions** cloud runners and route your local client traffic (macOS / Windows / Linux) through it using **Cloudflare Zero Trust Tunnels (`cloudflared`)**.

---

## 🏗️ Architecture

```text
[MacBook / Client Device]
   │
   ├── 1. OpenVPN Client (Connects to localhost:1194 TCP)
   │
   └── 2. cloudflared access tcp (Encapsulates traffic -> vpn.yourdomain.com)
            │
            ▼ (Encrypted Cloudflare Edge Network)
[Cloudflare Edge Network]
            │
            ▼
[GitHub Actions Cloud Runner (Ubuntu)]
   │
   ├── 3. cloudflared tunnel run (Token-authenticated daemon)
   │        │
   │        ▼ forwards to localhost:1194
   ├── 4. OpenVPN Server (TCP 1194, tun0, subnet 10.8.0.0/24)
   │        │
   │        ▼ iptables NAT Masquerade
   └── 5. GitHub / Azure Datacenter Egress (Your public IP becomes GitHub's IP)
```

---

## ⚡ Quickstart Guide

### Step 1: One-Time Cloudflare Tunnel Setup

1. Open your [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2. Navigate to **Networks** ➔ **Tunnels** ➔ **Create a tunnel**.
3. Select **Cloudflared**.
4. Name your tunnel (e.g., `github-vpn`).
5. Copy the **Tunnel Token** (the string starting with `eyJh...`).
6. In the **Public Hostname** tab:
   - **Subdomain**: `vpn` (or any subdomain)
   - **Domain**: Select your domain (e.g., `yourdomain.com`)
   - **Service Type**: `TCP`
   - **URL**: `localhost:1194`
7. Click **Save tunnel**.

---

### Step 2: Add Secret to GitHub

1. Go to your GitHub repository: **Settings** ➔ **Secrets and variables** ➔ **Actions**.
2. Click **New repository secret**.
3. Name: `CLOUDFLARE_TUNNEL_TOKEN`
4. Value: Paste your Cloudflare tunnel token.
5. Click **Add secret**.

---

### Step 3: Start the OpenVPN Server

1. In your GitHub repository, go to the **Actions** tab.
2. Select **OpenVPN Server via Cloudflare Tunnel** on the left.
3. Click **Run workflow** ➔ Select duration (up to 360 mins / 6 hours) ➔ Click **Run workflow**.
4. The workflow will:
   - Configure IP forwarding & NAT masquerading on the runner.
   - Generate all cryptographic keys (CA, Server, Client) and start OpenVPN in TCP mode.
   - Connect the Cloudflare Tunnel.
   - Upload the consolidated `client.ovpn` profile under **Artifacts**.

---

### Step 4: Connect from Your MacBook

1. Once the GitHub Actions run starts, click on it and download the **`openvpn-client-profile`** artifact.
2. Unzip it and place `client.ovpn` into this directory:
   ```bash
   mv ~/Downloads/openvpn-client-profile/client.ovpn ./
   ```
3. Run the automated macOS connector:
   ```bash
   ./connect-mac.sh vpn.yourdomain.com
   ```
4. Choose whether to connect directly in Terminal (`sudo openvpn`) or launch your favorite GUI app (OpenVPN Connect / Tunnelblick).

---

### Step 5: Verify Your Connection

Check your public egress IP in a new terminal:
```bash
curl https://icanhazip.com
```
Your public IP will now display the **Microsoft Azure / GitHub Actions Datacenter IP**!

---

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── openvpn.yml       # GitHub Actions workflow
├── connect-mac.sh            # 1-Click macOS bridge and connector script
├── .gitignore
└── README.md
```

---

## 🛡️ Security Features

- **No Public Open Ports on GitHub Runner:** Traffic travels strictly through the authenticated Cloudflare Zero Trust tunnel.
- **End-to-End Encryption:** Double layer of encryption — OpenVPN AES-256-GCM + Cloudflare Tunnel TLS/WebSocket encryption.
- **Ephemeral & Auto-Cleaned:** Keys and certificates are regenerated fresh on every workflow dispatch; certificates expire automatically and the runner disk is wiped upon job completion.
