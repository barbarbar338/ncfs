# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# Starting ngrok on background
# and using it on all templates.

ngrok config add-authtoken $NGROK_AUTH_TOKEN

ngrok tcp 127.0.0.1:$NGROK_TCP_PORT >/dev/null &

while ! curl -s localhost:4040/api/tunnels | grep -q "tcp://"; do
	sleep 1
done

ngrok_url=$(curl -s localhost:4040/api/tunnels | grep -o "tcp://[0-9a-z.-]*:[0-9]*")
parsed_ngrok_url=${ngrok_url/tcp:\/\//}

IFS=':' read -ra ADDR <<<"$parsed_ngrok_url"

export ngrok_host=${ADDR[0]}
export ngrok_port=${ADDR[1]}
