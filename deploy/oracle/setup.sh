#!/usr/bin/env bash
# Cài đặt lần đầu trên Oracle Cloud VM (Ubuntu 22.04)
# Chạy: bash deploy/oracle/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/etc/expense-manager/production.env"

echo "==> Expense Manager — Oracle Cloud setup"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Tạo $ENV_FILE từ env.example..."
  sudo mkdir -p /etc/expense-manager
  sudo cp "$SCRIPT_DIR/env.example" "$ENV_FILE"
  echo ""
  echo "!!! SỬA FILE CẤU HÌNH TRƯỚC KHI TIẾP TỤC !!!"
  echo "    sudo nano $ENV_FILE"
  echo "    (đổi MYSQL_PASSWORD, JWT_SECRET, GIT_REPO, GEMINI_API_KEY, MAIL_*)"
  echo ""
  read -r -p "Đã sửa xong production.env? [y/N] " ok
  if [[ "${ok,,}" != "y" ]]; then
    echo "Dừng. Chạy lại setup.sh sau khi sửa $ENV_FILE"
    exit 1
  fi
fi

# shellcheck disable=SC1091
source "$ENV_FILE"

: "${APP_DIR:=/home/ubuntu/Doantotnghiep2}"
: "${APP_USER:=ubuntu}"
: "${MYSQL_DATABASE:=expense_manager}"
: "${MYSQL_USER:=expense}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD chưa set trong $ENV_FILE}"

echo "==> Cài package hệ thống..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  openjdk-17-jdk \
  maven \
  mysql-server \
  nginx \
  git \
  python3 \
  python3-venv \
  python3-pip \
  curl \
  unzip

echo "==> Cấu hình MySQL..."
sudo systemctl enable mysql
sudo systemctl start mysql

sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "==> Clone / cập nhật source..."
if [[ ! -d "$APP_DIR/.git" ]]; then
  if [[ -z "${GIT_REPO:-}" || "$GIT_REPO" == *YOUR_USERNAME* ]]; then
    echo "GIT_REPO chưa đúng trong $ENV_FILE"
    exit 1
  fi
  git clone "$GIT_REPO" "$APP_DIR"
else
  cd "$APP_DIR"
  git pull --ff-only || true
fi

echo "==> Cài AI Service (Python venv)..."
cd "$APP_DIR/ai_service"
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# Đồng bộ GEMINI_* sang ai_service/.env
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  grep -q '^GEMINI_API_KEY=' "$APP_DIR/ai_service/.env" 2>/dev/null && \
    sed -i "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=${GEMINI_API_KEY}/" "$APP_DIR/ai_service/.env" || \
    echo "GEMINI_API_KEY=${GEMINI_API_KEY}" >> "$APP_DIR/ai_service/.env"
fi
grep -q '^GEMINI_MODEL=' "$APP_DIR/ai_service/.env" 2>/dev/null || \
  echo "GEMINI_MODEL=${GEMINI_MODEL:-gemini-2.5-flash-lite}" >> "$APP_DIR/ai_service/.env"

echo "==> Kiểm tra model .pt..."
missing=0
for f in classify_model.pt forecast_model.pt ocr_reco_model.pt; do
  if [[ ! -f "$APP_DIR/ai_service/models/$f" ]]; then
    echo "  THIẾU: ai_service/models/$f"
    missing=1
  else
    echo "  OK: $f"
  fi
done
if [[ "$missing" -eq 1 ]]; then
  echo ""
  echo "Upload model từ Windows (PowerShell):"
  echo "  .\\deploy\\oracle\\upload-models.ps1 -SshKey C:\\path\\key.pem -VmIp <IP>"
  echo ""
  read -r -p "Tiếp tục dù thiếu model? [y/N] " cont
  [[ "${cont,,}" == "y" ]] || exit 1
fi

echo "==> Build Backend..."
cd "$APP_DIR/backend"
mvn clean package -DskipTests -q

echo "==> Cài systemd services..."
sudo sed "s|%APP_DIR%|${APP_DIR}|g; s|%APP_USER%|${APP_USER}|g" \
  "$SCRIPT_DIR/systemd/expense-ai.service" | sudo tee /etc/systemd/system/expense-ai.service > /dev/null
sudo sed "s|%APP_DIR%|${APP_DIR}|g; s|%APP_USER%|${APP_USER}|g" \
  "$SCRIPT_DIR/systemd/expense-backend.service" | sudo tee /etc/systemd/system/expense-backend.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable expense-ai expense-backend

echo "==> Cấu hình Nginx..."
PUBLIC_IP="$(curl -s -m 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
sudo sed "s|SERVER_NAME|${PUBLIC_IP}|g" "$SCRIPT_DIR/nginx/expense.conf" | \
  sudo tee /etc/nginx/sites-available/expense > /dev/null
sudo ln -sf /etc/nginx/sites-available/expense /etc/nginx/sites-enabled/expense
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx

echo "==> Khởi động services..."
sudo systemctl restart expense-ai
sleep 5
sudo systemctl restart expense-backend

echo ""
echo "========== HOÀN TẤT =========="
echo "API:     http://${PUBLIC_IP}/api"
echo "Swagger: http://${PUBLIC_IP}/api/swagger-ui.html"
echo "Health:  http://${PUBLIC_IP}/health"
echo ""
echo "Kiểm tra:"
echo "  sudo systemctl status expense-ai expense-backend"
echo "  curl -s http://127.0.0.1:8000/health | python3 -m json.tool"
echo "  curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/swagger-ui.html"
echo ""
echo "Cập nhật code sau này: bash $APP_DIR/deploy/oracle/deploy-app.sh"
