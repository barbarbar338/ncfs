#!/bin/bash

# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# Config: update these variables according to your minecraft server and ngrok account
NGROK_TCP_PORT=25565            # Minecraft server port, default is 25565
NGROK_AUTH_TOKEN=""             # ngrok auth token, get it from https://dashboard.ngrok.com/auth/your-authtoken
CLOUDFLARE_AUTH_EMAIL=""        # Cloudflare auth email
CLOUDFLARE_API_KEY=""           # Cloudflare API key, get it from https://dash.cloudflare.com/profile/api-tokens => Global API Key 
CLOUDFLARE_ZONE_ID=""           # Cloudflare zone id
CLOUDFLARE_CNAME_RECORD_NAME="" # Cloudflare record name (server.mydomain.com), create a CNAME record in your Cloudflare dashboard and set the name to this value (you can put example.com to content for now)
CLOUDFLARE_SRV_RECORD_NAME=""   # Cloudflare record name (play.mydomain.com, use this while connecting to your server), create a SRV record in your Cloudflare dashboard and set the name to this value (you can put your CLOUDFLARE_CNAME_RECORD_NAME variable to content for now)

echo "🚀 NCFS: Starting NGROK to Cloudflare Forwarding Script..."

# Checking dependencies
echo "🔍 NCFS: Checking dependencies..."

# Check if snap is installed. If not, install it.
echo "🔍 DEPENDENCIES: Checking if snap is installed..."

if ! command -v snap &> /dev/null; then
    echo "❌ DEPENDENCIES: snap could not be found"
    echo "⬇️ DEPENDENCIES: Installing snap..."

    sudo apt update
    sudo apt install snapd
fi

# Check if ngrok is installed. If not, install it.
echo "🔍 DEPENDENCIES: Checking if ngrok is installed..."

if ! command -v ngrok &> /dev/null; then
    echo "❌ DEPENDENCIES: ngrok could not be found"
    echo "⬇️ DEPENDENCIES: Installing ngrok..."

    sudo snap install ngrok
fi

# Check if curl is installed. If not, install it.
echo "🔍 DEPENDENCIES: Checking if curl is installed..."

if ! command -v curl &> /dev/null; then
    echo "❌ DEPENDENCIES: curl could not be found"
    echo "⬇️ DEPENDENCIES: Installing curl..."

    sudo apt update
    sudo apt install curl
fi

# Checking cloudflare config
echo "🔍 NCFS: Checking Cloudflare config..."

# Get CNAME record from Cloudflare
echo "🔍 CF Checker: Getting CNAME record from Cloudflare..."

cname_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=CNAME&name=$CLOUDFLARE_CNAME_RECORD_NAME" \
                    -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
                    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                    -H "Content-Type: application/json")

# Check if record exists
if [[ $cname_record == *"\"count\":0"* ]]; then
    echo "❌ CF Checker: CNAME record does not exist in Cloudflare. You have to create it manually. Create a CNAME record in your Cloudflare dashboard and set the name to $CLOUDFLARE_CNAME_RECORD_NAME (you can put example.com to content for now)"
    exit 1
fi

# Get CNAME record id
cname_record_id=$(echo "$cname_record" | sed -E 's/.*"id":"(\w+)".*/\1/')

# Get SRV record from Cloudflare
echo "🔍 CF Checker: Getting SRV record from Cloudflare..."

srv_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=SRV&name=_minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME" \
                    -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
                    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                    -H "Content-Type: application/json")

# Check if record exists
if [[ $srv_record == *"\"count\":0"* ]]; then
    echo "❌ CF Checker: SRV record does not exist in Cloudflare. You have to create it manually. Create a SRV record in your Cloudflare dashboard and set the name to $CLOUDFLARE_SRV_RECORD_NAME (you can put $CLOUDFLARE_CNAME_RECORD_NAME to content for now)"
    exit 1
fi

# Get SRV record id
srv_record_id=$(echo "$srv_record" | sed -E 's/.*"id":"(\w+)".*/\1/')

# Starting ngrok
echo "🚀 NCFS: Starting NGROK..."

# Set NGROK auth token
echo "🔑 NGROK: Setting NGROK auth token..."

ngrok config add-authtoken $NGROK_AUTH_TOKEN

# Run NGROK on background
echo "🚀 NGROK: Starting NGROK on background..."

ngrok tcp $NGROK_TCP_PORT > /dev/null &

# Wait for NGROK to start
echo "🕑 NGROK: Waiting for NGROK to start..."

while ! curl -s localhost:4040/api/tunnels | grep -q "tcp://"; do
    sleep 1
done

echo "✅ NGROK: NGROK started successfully"

# Get NGROK URL
echo "🔗 NGROK: Getting NGROK URL..."

ngrok_url=$(curl -s localhost:4040/api/tunnels | grep -o "tcp://[0-9a-z.-]*:[0-9]*")
parsed_ngrok_url=${ngrok_url/tcp:\/\//}

IFS=':' read -ra ADDR <<< "$parsed_ngrok_url"
ngrok_host=${ADDR[0]}
ngrok_port=${ADDR[1]}

# Log NGROK URL
echo "🔗 NGROK: URL: $ngrok_url"
echo "🔗 NGROK: Parsed URL: $parsed_ngrok_url"
echo "🔗 NGROK: Host and Port: $ngrok_host - $ngrok_port"

# Update Cloudflare records
echo "📝 NCFS: Updating Cloudflare records..."

# Update CNAME record
echo "📝 CF Updater: Updating CNAME record..."

update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$cname_record_id" \
                     -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
                     -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"$ngrok_host\"}")

# Check if update is successful
case "$update" in
    *"\"success\":false"*)
        echo "❌ CF Updater: CNAME record could not be updated in Cloudflare. $update"
        exit 1
    ;;
    *)
        echo "✅ CF Updater: CNAME record updated in Cloudflare. $ngrok_host - $CLOUDFLARE_CNAME_RECORD_NAME"
    ;;
esac

# Update SRV record
echo "📝 CF Updater: Updating SRV record..."

update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$srv_record_id" \
                     -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
                     -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"SRV\",\"name\":\"_minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME\",\"data\": {\"name\":\"$CLOUDFLARE_SRV_RECORD_NAME\",\"port\":$ngrok_port,\"proto\":\"_tcp\",\"service\":\"_minecraft\",\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")

# Check if update is successful
case "$update" in
    *"\"success\":false"*)
        echo "❌ CF Updater: SRV record could not be updated in Cloudflare. $update"
        exit 1
    ;;
    *)
        echo "✅ CF Updater: SRV record updated in Cloudflare. $ngrok_host - _minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME"
    ;;
esac

# Done! Exit gracefully
echo "✅ NCFS: Done! Exiting gracefully..."

exit 0
