#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Hiago Dutra (hiagopdutra)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/lightningnetwork/lnd

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

fetch_and_deploy_gh_release "lnd-app" "lightningnetwork/lnd" "prebuild" "latest" "/opt/lnd" "lnd-linux-amd64-*.tar.gz"
install -m 755 /opt/lnd/lnd /usr/local/bin/lnd
install -m 755 /opt/lnd/lncli /usr/local/bin/lncli

if [[ -e /root/.lnd && ! -L /root/.lnd ]]; then
  rm -rf /root/.lnd
fi
ln -sfn /opt/lnd /root/.lnd

msg_info "Setting up Application"
mkdir -p /opt/lnd/data
cat <<EOF >/opt/lnd/README.md
# LND Container Notes

LND is installed in /opt/lnd and uses /root/.lnd as a symlink to that directory.

## Required configuration

Create /opt/lnd/lnd.conf before starting LND.

You can configure LND yourself, follow the RaspiBolt tutorials at https://raspibolt.org/, or optionally download helper scripts that configure LND, RTL, and static channel backups:

\`\`\`bash
mkdir -p /opt/proxmox-btc-tools/lnd
curl -fsSL https://raw.githubusercontent.com/hiagopdutra/proxmox-btc-tools/main/lnd/setup-lnd.sh -o /opt/proxmox-btc-tools/lnd/setup-lnd.sh
chmod +x /opt/proxmox-btc-tools/lnd/setup-lnd.sh
\`\`\`

Run the helper as root:

\`\`\`bash
/opt/proxmox-btc-tools/lnd/setup-lnd.sh
\`\`\`

## Start services

After /opt/lnd/lnd.conf is configured:

\`\`\`bash
systemctl start lnd
lncli create
\`\`\`

If RTL was installed, start it after the LND wallet and macaroon files exist:

\`\`\`bash
systemctl start rtl
\`\`\`
EOF
msg_ok "Set up Application"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/lnd.service
[Unit]
Description=LND Lightning Network Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lnd
ExecStart=/usr/local/bin/lnd
Restart=on-failure
RestartSec=5
TimeoutStopSec=60
LimitNOFILE=128000

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q lnd
msg_ok "Created Service"

read -r -p "${TAB3}Would you like to install RTL web UI?  " prompt_rtl
if [[ "${prompt_rtl,,}" =~ ^(y|yes)$ ]]; then
  NODE_VERSION="22" setup_nodejs
  fetch_and_deploy_gh_release "rtl" "Ride-The-Lightning/RTL" "tarball" "latest" "/opt/rtl"

  msg_info "Setting up RTL"
  cd /opt/rtl
  $STD npm ci --omit=dev --legacy-peer-deps
  msg_ok "Set up RTL"

  msg_info "Creating RTL Service"
  cat <<EOF >/etc/systemd/system/rtl.service
[Unit]
Description=Ride The Lightning
After=lnd.service network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/rtl
Environment=RTL_CONFIG_PATH=/opt/rtl
ExecStart=/usr/bin/node rtl
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable -q rtl
  msg_ok "Created RTL Service"
fi

read -r -p "${TAB3}Would you like to install Tor support?  " prompt_tor
if [[ "${prompt_tor,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Installing Dependencies"
  $STD apt install -y tor
  msg_ok "Installed Dependencies"

  msg_info "Configuring Tor"
  grep -q '^ControlPort 9051$' /etc/tor/torrc 2>/dev/null || cat <<EOF >>/etc/tor/torrc

# community-scripts: lnd tor control
ControlPort 9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1
EOF

  msg_info "Updating LND Service"
  cat <<EOF >/etc/systemd/system/lnd.service
[Unit]
Description=LND Lightning Network Daemon
After=network.target tor.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lnd
ExecStart=/usr/local/bin/lnd
Restart=on-failure
RestartSec=5
TimeoutStopSec=60
LimitNOFILE=128000

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable -q --now tor
  systemctl reenable -q lnd
  msg_ok "Configured Tor"
fi

echo
echo -e "${INFO}${YW} Next steps:${CL}"
echo -e "${TAB}Read the container notes with ${BGN}cat /opt/lnd/README.md${CL}."

motd_ssh
customize
cleanup_lxc
