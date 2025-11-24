#!/bin/bash

echo "====================================="
echo "     ZORO TROJAN WEBSOCKET SETUP     "
echo "====================================="

read -p "اختر REGION (مثال: us-central1): " REGION
read -p "اختر حجم CPU (1 - 4): " CPU
read -p "اختر حجم RAM بالجيغا (1 - 6): " RAM
read -p "ضع HEADER HOST (مثال: youtube.com): " HOST
read -p "ضع TOKEN البوت: " BOT_TOKEN
read -p "ضع ID الخاص بك: " USER_ID

SERVICE_NAME="zoro-trojan-$(date +%s)"

mkdir -p trojan-server
cd trojan-server

#########################################
# config.json
#########################################
cat > config.json <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 8080,
  "password": ["zoro40pass"],
  "websocket": {
    "enabled": true,
    "path": "/zoro40",
    "host": "$HOST"
  },
  "ssl": {
    "cert": "/etc/trojan/cert.crt",
    "key": "/etc/trojan/cert.key"
  },
  "mux": {
    "enabled": true,
    "concurrency": 32
  }
}
EOF

#########################################
# Dockerfile
#########################################
cat > Dockerfile <<EOF
FROM alpine:latest

RUN apk add --no-cache curl unzip ca-certificates openssl

RUN curl -L https://github.com/p4gefau1t/trojan-go/releases/latest/download/trojan-go-linux-amd64.zip -o /tmp/tg.zip \
    && unzip /tmp/tg.zip -d /usr/local/bin/ \
    && rm /tmp/tg.zip

RUN mkdir -p /etc/trojan

COPY config.json /etc/trojan/config.json
COPY cert.crt /etc/trojan/cert.crt
COPY cert.key /etc/trojan/cert.key

EXPOSE 8080

CMD ["/usr/local/bin/trojan-go", "-config", "/etc/trojan/config.json"]
EOF

#########################################
# إنشاء شهادة
#########################################
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout cert.key -out cert.crt \
  -days 365 \
  -subj "/C=US/ST=CA/L=LA/O=Zoro/OU=IT/CN=$HOST"

#########################################
# Cloud Build
#########################################
gcloud builds submit --tag gcr.io/\$GOOGLE_CLOUD_PROJECT/$SERVICE_NAME

#########################################
# Cloud Run Deploy
#########################################
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/\$GOOGLE_CLOUD_PROJECT/$SERVICE_NAME \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --cpu $CPU \
  --memory ${RAM}Gi \
  --port 8080

#########################################
# الحصول على رابط الخدمة
#########################################
URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format "value(status.url)")

#########################################
# إنشاء رابط Trojan WebSocket
#########################################
LINK="trojan://zoro40pass@$URL:443?type=ws&host=$HOST&path=/zoro40#ZORO"

echo "====================================="
echo "🔥 رابط السيرفر جاهز:"
echo "$LINK"
echo "====================================="

#########################################
# إرسال الرابط إلى البوت
#########################################
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
     -d chat_id="${USER_ID}" \
     -d text="🔥 سيرفر Trojan WebSocket جاهز 100%:\n\n${LINK}"

echo "تم إرسال الرابط إلى البوت ✔️"
echo "كل الملفات موجودة داخل مجلد trojan-server/"
