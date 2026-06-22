#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="/etc/expense-manager/production.env"
[[ -f "$ENV_FILE" ]] || { echo "Chưa setup."; exit 1; }
# shellcheck disable=SC1091
source "$ENV_FILE"
: "${APP_DIR:=/home/ubuntu/doancuanhat}"

cd "$APP_DIR"
git pull --ff-only
cd backend
mvn clean package -DskipTests -q
sudo systemctl restart expense-backend
echo "Deploy backend xong."
sudo systemctl --no-pager status expense-backend | head -10
