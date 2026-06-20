#!/usr/bin/env bash
# Cập nhật code + rebuild + restart (chạy trên VM sau khi git push)
set -euo pipefail

ENV_FILE="/etc/expense-manager/production.env"
[[ -f "$ENV_FILE" ]] || { echo "Chưa setup. Chạy setup.sh trước."; exit 1; }
# shellcheck disable=SC1091
source "$ENV_FILE"
: "${APP_DIR:=/home/ubuntu/Doantotnghiep2}"

echo "==> Pull code..."
cd "$APP_DIR"
git pull --ff-only

echo "==> Cập nhật AI dependencies..."
cd "$APP_DIR/ai_service"
source .venv/bin/activate
pip install -r requirements.txt -q
deactivate

echo "==> Build backend..."
cd "$APP_DIR/backend"
mvn clean package -DskipTests -q

echo "==> Restart services..."
sudo systemctl restart expense-ai
sleep 8
sudo systemctl restart expense-backend

echo "==> Trạng thái:"
sudo systemctl --no-pager status expense-ai expense-backend | head -20
curl -sf http://127.0.0.1:8000/health && echo ""
echo "Deploy xong."
