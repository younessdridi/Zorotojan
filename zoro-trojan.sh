#!/bin/bash

set -e

PROJECT_ID="qwiklabs-gcp-01-18d229542ace"
REGION="us-central1"

echo "🔧 إعداد Google Cloud..."
gcloud config set project $PROJECT_ID >/dev/null

# === إعداد المتغيرات ===
read -p "أدخل توكن البوت: " BOT_TOKEN
read -p "أدخل آيدي التليغرام الذي يستقبل السيرفر: " ADMIN_ID
read -p "أدخل كلمة سر Trojan (اتركها فارغة لتوليد كلمة سر تلقائية): " TROJAN_PASS

if [ -z "$TROJAN_PASS" ]; then
    TROJAN_PASS=$(openssl rand -hex 8)
    echo "تم توليد كلمة سر تلقائياً: $TROJAN_PASS"
fi

UUID=$(uuidgen)
PORT=8080
PATH_WS="/zoro"

# إنشاء مجلد العمل
rm -rf zoro-trojan
mkdir zoro-trojan
cd zoro-trojan

# === Dockerfile ===
cat <<EOF > Dockerfile
FROM teddysun/xray:latest
COPY config.json /etc/xray/config.json
COPY index.html /www/index.html
CMD ["xray", "-config", "/etc/xray/config.json"]
EOF

# === صفحة مزيفة ===
cat <<EOF > index.html
<html><body><h1 style="text-align:center;margin-top:50px;font-family:sans-serif;">ZORO SERVER ACTIVE ✓</h1></body></html>
EOF

# === ملف config.json ===
cat <<EOF > config.json
{
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${TROJAN_PASS}",
            "email": "zoro"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${PATH_WS}"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

echo "🚀 نشر التطبيق على Cloud Run..."

gcloud run deploy zoro-trojan \
    --source . \
    --region $REGION \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --port $PORT >/dev/null

URL=$(gcloud run services describe zoro-trojan --region $REGION --format 'value(status.url)')

# === إنشاء رابط Trojan النهائي ===
TROJAN_LINK="trojan://${TROJAN_PASS}@${URL#https://}:${PORT}?type=ws&path=${PATH_WS}&security=none#ZORO-TROJAN"

echo "🔗 رابط التروجان جاهز:"
echo "$TROJAN_LINK"

# === إرسال للبوت ===
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${ADMIN_ID}" \
    -d text="🔥 تم إنشاء سيرفر Trojan بنجاح

🔗 ${TROJAN_LINK}"

echo "🎉 تم إرسال السيرفر للبوت!"
