#!/bin/bash

# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# We were using some commands
# to check if dependencies are installed
# but we decided to remove them
# because we are using Docker now

echo "Using Minecraft template."

source ./shared/getconfig.sh
source ./shared/cf.sh
source ./shared/ngrok.sh

update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$cname_record_id" \
	-H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
	-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
	-H "Content-Type: application/json" \
	--data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"$ngrok_host\"}")

case "$update" in
*"\"success\":false"*)
	echo "CNAME record could not be updated in Cloudflare. $update"
	exit 1
	;;
esac

if [ "$CLOUDFLARE_SRV_RECORD_NAME" != "_DEFAULT_VALUE_DO_NOT_USE_IT" ]; then
	update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$srv_record_id" \
		-H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
		-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
		-H "Content-Type: application/json" \
		--data "{\"type\":\"SRV\",\"name\":\"_minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME\",\"data\": {\"name\":\"$CLOUDFLARE_SRV_RECORD_NAME\",\"port\":$ngrok_port,\"proto\":\"_tcp\",\"service\":\"_minecraft\",\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")

	case "$update" in
	*"\"success\":false"*)
		echo "❌ CF Updater: SRV record could not be updated in Cloudflare. $update"
		exit 1
		;;
	esac
fi

tail -f "/dev/null"

exit 0
