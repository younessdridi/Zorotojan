#!/bin/bash

set -e

echo ""
echo "=============================="
echo "      ZORO TROJAN SETUP       "
echo "=============================="
echo ""

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

log() { echo -e "${GREEN}[+]${NC} $1"; }
ask() { read -rp "$1: " ans; echo "$ans"; }

# -------------------------------
#   USER INPUTS
# -------------------------------

TOKEN=$(ask "ادخل توكن البوت (Telegram BOT Token)")
ADMIN_ID=$(ask "ادخل ايدي الادمن (Telegram ID)")
SERVER_NAME=$(ask "ادخل اسم السيرفر (مثال: ZORO-TROJAN)")
PASSWORD=$(ask "ادخل كلمة المرور (اتركه فارغ يولد تلقائيا)")

if [[ -z "$PASSWORD" ]]; then
  PASSWORD=$(openssl rand -hex 8)
  log "تم توليد كلمة مرور تلقائية: $PASSWORD"
fi

PROJECT_ID=$(ask "ادخل Project ID (اتركه فارغ لاختيار تلقائي)")
if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="zoro-$RANDOM"
  log "تم إنشاء PROJECT ID تلقائياً: $PROJECT_ID"
fi

echo ""
echo "اختار المنطقة (Region):"
echo "1) us-central1"
echo "2) europe-west1"
echo "3) asia-south1"
REGION_CHOICE=$(ask "اختر رقم المنطقة")

case $REGION_CHOICE in
  1) REGION="us-central1" ;;
  2) REGION="europe-west1" ;;
  3) REGION="asia-south1" ;;
  *) REGION="us-central1" ;;
esac

echo ""
echo "اختار CPU:"
echo "1) 1 vCPU"
echo "2) 2 vCPU"
CPU_CHOICE=$(ask "اختر رقم")

case $CPU_CHOICE in
  1) CPU="1" ;;
  2) CPU="2" ;;
  *) CPU="1" ;;
esac

echo ""
echo "اختار RAM:"
echo "1) 512MB"
echo "2) 1GB"
echo "3) 2GB"
RAM_CHOICE=$(ask "اختر رقم")

case $RAM_CHOICE in
  1) RAM="512Mi" ;;
  2) RAM="1Gi" ;;
  3) RAM="2Gi" ;;
  *) RAM="1Gi" ;;
esac

# -------------------------------
#   DIRECTORY
# -------------------------------
mkdir -p zoro-trojan
cd zoro-trojan

# -------------------------------
#   DOCKERFILE
# -------------------------------
cat <<EOF > Dockerfile
FROM alpine:latest

RUN apk add --no-cache curl bash nginx openssl

WORKDIR /app

COPY config.json /app/config.json
COPY index.html /var/www/html/index.html

EXPOSE 443

CMD ["bash", "-c", "nginx && /app/trojan-go -config /app/config.json"]
EOF

# -------------------------------
#   CONFIG.JSON (TROJAN)
# -------------------------------
cat <<EOF > config.json
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "password": ["$PASSWORD"],
  "log_level": 1,
  "ssl": {
    "cert": "/etc/ssl/cert.pem",
    "key": "/etc/ssl/key.pem",
    "fallback_port": 80,
    "sni": "cdn.jsdelivr.net"
  },
  "websocket": {
    "enabled": true,
    "path": "/zoro",
    "host": "cdn.jsdelivr.net"
  }
}
EOF

# -------------------------------
#   HTML PAGE
# -------------------------------
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
<title>ZORO SERVER</title>
<style>
body {
  background: black;
  color: #0f0;
  font-family: monospace;
  text-align: center;
  margin-top: 120px;
}
h1 {
  font-size: 40px;
  text-shadow: 0 0 15px #0f0;
}
</style>
</head>
<body>
<h1>ZORO TROJAN SERVER</h1>
<p>Server Active ✓</p>
</body>
</html>
EOF

# -------------------------------
#   DEPLOY CLOUD RUN
# -------------------------------
log "جاري تفعيل Cloud Run…"

gcloud projects create $PROJECT_ID >/dev/null 2>&1 || true
gcloud config set project $PROJECT_ID >/dev/null
gcloud services enable run.googleapis.com >/dev/null

log "بناء الصورة…"
gcloud builds submit --tag gcr.io/$PROJECT_ID/zoro-trojan .

log "نشر Cloud Run…"
URL=$(gcloud run deploy zoro-trojan \
  --image gcr.io/$PROJECT_ID/zoro-trojan \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --cpu $CPU \
  --memory $RAM \
  --port 443 \
  --quiet \
  | grep "URL:" | awk '{print $2}')

log "تم نشر السيرفر بنجاح!"
log "الرابط: $URL"

# -------------------------------
#   TROJAN LINK
# -------------------------------
TROJAN_LINK="trojan://$PASSWORD@$URL:443?type=ws&host=cdn.jsdelivr.net&path=/zoro#${SERVER_NAME}"

log "إرسال المعلومات للبوت…"

MESSAGE="🔥 *ZORO TROJAN SERVER READY* 🔥

*Name:* $SERVER_NAME
*URL:* $URL
*Password:* $PASSWORD
*Protocol:* TROJAN WS TLS
*Region:* $REGION

🔗 *Trojan Link:*  
$TROJAN_LINK
"

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d chat_id="$ADMIN_ID" \
  -d text="$MESSAGE" \
  -d parse_mode="Markdown"

log "اكتمل كل شيء ✓"
