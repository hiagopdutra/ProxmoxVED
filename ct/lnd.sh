#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Hiago Dutra (hiagopdutra)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/lightningnetwork/lnd

APP="LND"
var_tags="${var_tags:-bitcoin;lightning}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/lnd ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "lnd-app" "lightningnetwork/lnd"; then
    msg_info "Stopping Service"
    [[ -d /opt/rtl ]] && systemctl stop rtl 2>/dev/null || true
    systemctl stop lnd
    msg_ok "Stopped Service"

    msg_info "Backing up Data"
    [[ -f /opt/lnd/lnd.conf ]] && cp /opt/lnd/lnd.conf /opt/lnd.conf.bak
    [[ -d /opt/lnd/data ]] && cp -r /opt/lnd/data /opt/lnd-data.bak
    msg_ok "Backed up Data"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "lnd-app" "lightningnetwork/lnd" "prebuild" "latest" "/opt/lnd" "lnd-linux-amd64-*.tar.gz"
    install -m 755 /opt/lnd/lnd /usr/local/bin/lnd
    install -m 755 /opt/lnd/lncli /usr/local/bin/lncli

    msg_info "Restoring Data"
    if [[ -f /opt/lnd.conf.bak ]]; then
      cp /opt/lnd.conf.bak /opt/lnd/lnd.conf
      rm -f /opt/lnd.conf.bak
    fi
    if [[ -d /opt/lnd-data.bak ]]; then
      mkdir -p /opt/lnd/data
      cp -r /opt/lnd-data.bak/. /opt/lnd/data
      rm -rf /opt/lnd-data.bak
    fi
    msg_ok "Restored Data"

    msg_info "Starting Service"
    systemctl start lnd
    [[ -d /opt/rtl ]] && systemctl start rtl 2>/dev/null || true
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi

  if [[ -d /opt/rtl ]] && check_for_gh_release "rtl" "Ride-The-Lightning/RTL"; then
    msg_info "Stopping Service"
    systemctl stop rtl
    msg_ok "Stopped Service"

    msg_info "Backing up Configuration"
    [[ -f /opt/rtl/RTL-Config.json ]] && cp /opt/rtl/RTL-Config.json /opt/rtl-RTL-Config.json.bak
    msg_ok "Backed up Configuration"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "rtl" "Ride-The-Lightning/RTL" "tarball" "latest" "/opt/rtl"

    msg_info "Updating Application"
    cd /opt/rtl
    $STD npm ci --omit=dev --legacy-peer-deps
    msg_ok "Updated Application"

    msg_info "Restoring Configuration"
    if [[ -f /opt/rtl-RTL-Config.json.bak ]]; then
      cp /opt/rtl-RTL-Config.json.bak /opt/rtl/RTL-Config.json
      rm -f /opt/rtl-RTL-Config.json.bak
    fi
    msg_ok "Restored Configuration"

    msg_info "Starting Service"
    systemctl start rtl
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} LND peer port:${CL}"
echo -e "${TAB}${BGN}9735${CL}"
echo -e "${INFO}${YW} If you installed RTL, access it at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
