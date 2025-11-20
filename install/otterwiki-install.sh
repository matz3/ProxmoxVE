#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: matz3
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/redimp/otterwiki

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  build-essential \
  python3-{dev,venv}
msg_ok "Installed Dependencies"

msg_info "Setting up Data"
mkdir -p /opt/otterwiki/app-data
git init -b main /opt/otterwiki/app-data/repository
msg_ok "Set up Data"

msg_info "Configuring An Otter Wiki"
{
  echo "REPOSITORY='/opt/otterwiki/app-data'"
  echo "SQLALCHEMY_DATABASE_URI='sqlite:///opt/otterwiki/app-data/db.sqlite'"
  echo "SECRET_KEY='$(python -c 'import secrets; print(secrets.token_hex())')'"
} >> /opt/otterwiki/settings.cfg
msg_ok "Configured An Otter Wiki"

msg_info "Setup An Otter Wiki"
fetch_and_deploy_gh_release "otterwiki" "redimp/otterwiki"
python3 -m venv /opt/otterwiki/venv
/opt/otterwiki/venv/bin/pip install -U pip uwsgi
/opt/otterwiki/venv/bin/pip install .
msg_ok "Setup otterwiki"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/otterwiki.service
[Unit]
Description=otterwiki Service
After=network.target

[Service]
Environment="OTTERWIKI_SETTINGS=/opt/otterwiki/settings.cfg"

[Service]
ExecStart=/opt/otterwiki/venv/bin/uwsgi --http 127.0.0.1:8080 --master --enable-threads --die-on-term -w otterwiki.server:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now otterwiki
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt -y autoremove
$STD apt -y autoclean
$STD apt -y clean
msg_ok "Cleaned"
