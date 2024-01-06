# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# Making cloudflare configurations here.
# We are using Cloudflare API to update DNS records.

cname_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=CNAME&name=$CLOUDFLARE_CNAME_RECORD_NAME" \
	-H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
	-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
	-H "Content-Type: application/json")

if [[ $cname_record == *"\"count\":0"* ]]; then
	echo "CNAME record does not exist in Cloudflare. You have to create it manually. Create a CNAME record in your Cloudflare dashboard and set the name to $CLOUDFLARE_CNAME_RECORD_NAME (you can put example.com to content for now)"
	exit 1
fi

cname_record_id=$(echo "$cname_record" | sed -E 's/.*"id":"(\w+)".*/\1/')

srv_record_id="_DEFAULT_VALUE_DO_NOT_USE_IT"

if [ "$CLOUDFLARE_SRV_RECORD_NAME" != "_DEFAULT_VALUE_DO_NOT_USE_IT" ]; then
	srv_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=SRV&name=_minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME" \
		-H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
		-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
		-H "Content-Type: application/json")

	if [[ $srv_record == *"\"count\":0"* ]]; then
		echo "SRV record does not exist in Cloudflare. You have to create it manually. Create a SRV record in your Cloudflare dashboard and set the name to _minecraft._tcp.$CLOUDFLARE_SRV_RECORD_NAME, port to $NGROK_TCP_PORT, target to $CLOUDFLARE_CNAME_RECORD_NAME"
		exit 1
	fi

	srv_record_id=$(echo "$srv_record" | sed -E 's/.*"id":"(\w+)".*/\1/')
fi

export cname_record_id="$cname_record_id"
export srv_record_id="$srv_record_id"
