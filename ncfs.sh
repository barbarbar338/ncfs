#!/bin/bash

# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

get_variable() {
    local variable_name="$1"
    local config_file="$2"
    local force="$3"

    if [ -n "${!variable_name}" ]; then
        selected_value="${!variable_name}"
    else
        if [ -f "$config_file" ]; then
            selected_value=$(jq -r ".$variable_name" "$config_file")
            if [ "$selected_value" == "null" ]; then
                if [ "$force" == true ]; then
                    echo "$variable_name not found in config file and environment variables. Exiting."
                    exit 1
                else
                    echo "$variable_name not found in config file and environment variables. Using default value."
                    selected_value="_DEFAULT_VALUE_DO_NOT_USE_IT"
                fi
            fi
        else
            if [ "$force" == true ]; then
                echo "$variable_name not found in config file and environment variables. Exiting."
                exit 1
            else
                echo "$variable_name not found in config file and environment variables. Using default value."
                selected_value="_DEFAULT_VALUE_DO_NOT_USE_IT"
            fi
        fi
    fi

    echo "$selected_value"
}

NGROK_AUTH_TOKEN=$(get_variable "NGROK_AUTH_TOKEN" "config.json" true)
NGROK_TCP_PORT=$(get_variable "NGROK_TCP_PORT" "config.json" true)
CLOUDFLARE_AUTH_EMAIL=$(get_variable "CLOUDFLARE_AUTH_EMAIL" "config.json" true)
CLOUDFLARE_API_KEY=$(get_variable "CLOUDFLARE_API_KEY" "config.json" true)
CLOUDFLARE_ZONE_ID=$(get_variable "CLOUDFLARE_ZONE_ID" "config.json" true)
CLOUDFLARE_CNAME_RECORD_NAME=$(get_variable "CLOUDFLARE_CNAME_RECORD_NAME" "config.json" true)
CLOUDFLARE_SRV_RECORD_NAME=$(get_variable "CLOUDFLARE_SRV_RECORD_NAME" "config.json" false)
CLOUDFLARE_SRV_RECORD_PREIX=$(get_variable "CLOUDFLARE_SRV_RECORD_PREIX" "config.json" false)

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

ngrok config add-authtoken $NGROK_AUTH_TOKEN

ngrok tcp 127.0.0.1:$NGROK_TCP_PORT >/dev/null &

while ! curl -s localhost:4040/api/tunnels | grep -q "tcp://"; do
	sleep 1
done

ngrok_url=$(curl -s localhost:4040/api/tunnels | grep -o "tcp://[0-9a-z.-]*:[0-9]*")
parsed_ngrok_url=${ngrok_url/tcp:\/\//}

IFS=':' read -ra ADDR <<<"$parsed_ngrok_url"

ngrok_host=${ADDR[0]}
ngrok_port=${ADDR[1]}

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
		--data "{\"type\":\"SRV\",\"name\":\"$CLOUDFLARE_SRV_RECORD_PREIX.$CLOUDFLARE_SRV_RECORD_NAME\",\"data\": {\"name\":\"$CLOUDFLARE_SRV_RECORD_NAME\",\"port\":$ngrok_port,\"proto\":\"_tcp\",\"service\":\"_minecraft\",\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")

	case "$update" in
	*"\"success\":false"*)
		echo "❌ CF Updater: SRV record could not be updated in Cloudflare. $update"
		exit 1
		;;
	esac
fi

tail -f "/dev/null"

exit 0
