#!/usr/bin/env bash
# Cài backend Spring Boot trên AWS EC2 (Ubuntu 22.04)
# MySQL: AWS RDS | AI: Hugging Face Space
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/etc/expense-manager/production.env"

echo "==> Expense Manager — AWS EC2 backend setup"

if [[ ! -f "$ENV_FILE" ]]; then
  sudo mkdir -p /etc/expense-manager
  sudo cp "$SCRIPT_DIR/env.example" "$ENV_FILE"
  echo ""
  echo "!!! Sửa $ENV_FILE trước (RDS URL, PYTHON_AI_API_URL, JWT_SECRET, MAIL_*) !!!"
  echo "    sudo nano $ENV_FILE"
  read -r -p "Đã sửa xong? [y/N] " ok
  [[ "${ok,,}" == "y" ]] || exit 1
fi

# shellcheck disable=SC1091
source "$ENV_FILE"
: "${APP_DIR:=/home/ubuntu/doancuanhat}"
: "${APP_USER:=ubuntu}"
: "${SPRING_DATASOURCE_URL:?Set SPRING_DATASOURCE_URL trong production.env}"
: "${PYTHON_AI_API_URL:?Set PYTHON_AI_API_URL (Hugging Face Space URL)}"

echo "==> Cài package..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  openjdk-17-jdk maven nginx git curl

echo "==> Clone / pull code..."
if [[ ! -d "$APP_DIR/.git" ]]; then
  git clone "${GIT_REPO:-https://github.com/hoangnhata/doancuanhat.git}" "$APP_DIR"
else
  cd "$APP_DIR" && git pull --ff-only || true
fi

echo "==> Build backend..."
cd "$APP_DIR/backend"
mvn clean package -DskipTests -q

echo "==> Systemd..."
sudo sed "s|%APP_DIR%|${APP_DIR}|g; s|%APP_USER%|${APP_USER}|g" \
  "$SCRIPT_DIR/systemd/expense-backend.service" | sudo tee /etc/systemd/system/expense-backend.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable expense-backend

echo "==> Nginx..."
PUBLIC_IP="$(curl -s -m 5 http://checkip.amazonaws.com 2>/dev/null || hostname -I | awk '{print $1}')"
sudo sed "s|SERVER_NAME|${PUBLIC_IP}|g" "$SCRIPT_DIR/nginx/expense.conf" | \
  sudo tee /etc/nginx/sites-available/expense > /dev/null
sudo ln -sf /etc/nginx/sites-available/expense /etc/nginx/sites-enabled/expense
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx

echo "==> Start backend..."
sudo systemctl restart expense-backend
sleep 10
sudo systemctl --no-pager status expense-backend | head -15 || true

echo ""
echo "========== XONG =========="
echo "API:     http://${PUBLIC_IP}/api"
echo "Swagger: http://${PUBLIC_IP}/api/swagger-ui.html"
echo ""
echo "Kiểm tra kết nối RDS + HF:"
echo "  sudo journalctl -u expense-backend -n 50 --no-pager"
