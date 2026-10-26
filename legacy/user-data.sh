#!/bin/bash
# LEGACY: EC2 bootstrap script used before the move to EKS (kept for reference).
# Every instance built itself at boot, so two servers could end up with
# different package versions depending on when they were launched.
set -euo pipefail

dnf install -y python3.12 python3.12-pip git

useradd --system --home /opt/demo-api demo || true
git clone https://example.com/demo-api.git /opt/demo-api   # placeholder URL
cd /opt/demo-api/app
python3.12 -m pip install -r requirements.txt

cat >/etc/systemd/system/demo-api.service <<'UNIT'
[Unit]
Description=demo-api
After=network.target

[Service]
User=demo
WorkingDirectory=/opt/demo-api/app
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now demo-api
