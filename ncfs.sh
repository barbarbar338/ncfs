#!/bin/bash

# Copyright © 2023-2025 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

echo "Starting NCFS..."

# Function to get variables from either config.json or environment
get_variable() {
    local var_name="$1"
    local optional="${2:-false}"
    local value

    # Check environment variable
    value="${!var_name}"
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi

    # Check config.json using jq
    if [ -f "./config.json" ]; then
        value=$(jq -r --arg v "$var_name" '.[$v] // empty' ./config.json)
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            echo "$value"
            return 0
        fi
    fi

    # Not found
    if [ "$optional" = "true" ]; then
        echo ""
        return 0
    else
        echo "Error: Variable '$var_name' not found in environment or config.json." >&2
        exit 1
    fi
}

# Function to check if a port is open
check_port_open() {
    local host=$1
    local port=$2
    local timeout=$3
    
    echo "Checking if port $port is open on $host (timeout: ${timeout}s)..."
    
    # Try to connect using timeout and netcat
    if timeout $timeout bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "Port $port is open on $host"
        return 0
    else
        echo "Port $port is NOT open on $host"
        return 1
    fi
}

# Load required variables
CLOUDFLARE_AUTH_EMAIL=$(get_variable "CLOUDFLARE_AUTH_EMAIL")
CLOUDFLARE_ZONE_ID=$(get_variable "CLOUDFLARE_ZONE_ID")
CLOUDFLARE_CNAME_RECORD_NAME=$(get_variable "CLOUDFLARE_CNAME_RECORD_NAME")
NGROK_AUTH_TOKEN=$(get_variable "NGROK_AUTH_TOKEN")
NGROK_TCP_PORT=$(get_variable "NGROK_TCP_PORT")

# Load optional variables
CLOUDFLARE_API_KEY=$(get_variable "CLOUDFLARE_API_KEY" true)
CLOUDFLARE_API_TOKEN=$(get_variable "CLOUDFLARE_API_TOKEN" true)
CLOUDFLARE_SRV_RECORD_NAME=$(get_variable "CLOUDFLARE_SRV_RECORD_NAME" true)
CLOUDFLARE_SRV_RECORD_PREFIX=$(get_variable "CLOUDFLARE_SRV_RECORD_PREFIX" true)

# Check if either CLOUDFLARE_API_KEY or CLOUDFLARE_API_TOKEN exists
if [ -n "$CLOUDFLARE_API_KEY" ] || [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo "At least one Cloudflare API credential is set."
else
    echo "ERROR: No Cloudflare API credentials found." >&2
    exit 1
fi

# Diagnostic section - check Cloudflare authentication
echo "=== TESTING CLOUDFLARE AUTHENTICATION ==="
if [ -n "$CLOUDFLARE_AUTH_EMAIL" ] && [ -n "$CLOUDFLARE_API_KEY" ] && [ -n "$CLOUDFLARE_ZONE_ID" ]; then
    echo "Testing API Key authentication method..."
    cf_auth_test=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
        -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json")
    
    echo "API Key Auth Test Result: $cf_auth_test"
    
    if [[ $cf_auth_test == *"\"success\":true"* ]]; then
        echo "API Key authentication successful!"
        CLOUDFLARE_AUTH_METHOD="API_KEY"
    else
        echo "API Key authentication failed!"
    fi
fi

if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Testing API Token authentication method..."
    cf_token_test=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    echo "API Token Auth Test Result: $cf_token_test"
    
    if [[ $cf_token_test == *"\"success\":true"* ]]; then
        echo "API Token authentication successful!"
        CLOUDFLARE_AUTH_METHOD="API_TOKEN"
    else
        echo "API Token authentication failed!"
    fi
fi

if [ -z "$CLOUDFLARE_AUTH_METHOD" ]; then
    echo "ERROR: Could not authenticate with Cloudflare. Please check your API Key/Token and permissions."
    echo "If using API Key, ensure CLOUDFLARE_AUTH_EMAIL and CLOUDFLARE_API_KEY are set correctly."
    echo "If using API Token, ensure CLOUDFLARE_API_TOKEN is set correctly."
    echo "Will continue but DNS updates may fail."
fi
echo "=== END AUTHENTICATION TEST ==="

NGROK_TCP_PORT="${NGROK_TCP_PORT:-25565}"
echo "Using TCP port: $NGROK_TCP_PORT"

# If DOCKER_NETWORK is set, use it, otherwise use localhost
TARGET_HOST="${DOCKER_NETWORK:-localhost}"
echo "Using target host: $TARGET_HOST"

# Check if the target port is actually open
echo "=== CHECKING TARGET SERVICE ==="
PORT_RETRY_COUNT=12
PORT_RETRY_DELAY=5
PORT_CHECK_TIMEOUT=2

for i in $(seq 1 $PORT_RETRY_COUNT); do
    echo "Port check attempt $i of $PORT_RETRY_COUNT"
    if check_port_open "$TARGET_HOST" "$NGROK_TCP_PORT" "$PORT_CHECK_TIMEOUT"; then
        echo "Target service is running and accepting connections on $TARGET_HOST:$NGROK_TCP_PORT"
        TARGET_SERVICE_AVAILABLE=true
        break
    else
        echo "No service detected on $TARGET_HOST:$NGROK_TCP_PORT, retrying in $PORT_RETRY_DELAY seconds..."
        sleep $PORT_RETRY_DELAY
    fi
done

if [ "$TARGET_SERVICE_AVAILABLE" != "true" ]; then
    echo "WARNING: No service detected on $TARGET_HOST:$NGROK_TCP_PORT after $PORT_RETRY_COUNT attempts."
    echo "We will still set up ngrok and DNS records, but they may not work correctly."
    echo "Please ensure your target service is running and accessible on $TARGET_HOST:$NGROK_TCP_PORT"
fi
echo "=== END TARGET SERVICE CHECK ==="

CLOUDFLARE_CNAME_RECORD_NAME="${CLOUDFLARE_CNAME_RECORD_NAME:-server.example.com}"
echo "Using CNAME record name: $CLOUDFLARE_CNAME_RECORD_NAME"

# Use a single SRV record in standard format (_service._proto.domain.tld)
CLOUDFLARE_SRV_RECORD="${CLOUDFLARE_SRV_RECORD:-_minecraft._tcp.example.com}"
echo "Using SRV record: $CLOUDFLARE_SRV_RECORD"

# Parse the SRV record to get service, proto, and domain parts
if [[ "$CLOUDFLARE_SRV_RECORD" =~ ^(_[^.]+)\.(_[^.]+)\.(.*) ]]; then
    SRV_SERVICE="${BASH_REMATCH[1]}"
    SRV_PROTO="${BASH_REMATCH[2]}"
    SRV_DOMAIN="${BASH_REMATCH[3]}"
    echo "Parsed SRV record - Service: $SRV_SERVICE, Protocol: $SRV_PROTO, Domain: $SRV_DOMAIN"
else
    echo "WARNING: SRV record doesn't match the expected format (_service._proto.domain.tld)"
    echo "SRV record may not work correctly."
    SRV_SERVICE="_minecraft"
    SRV_PROTO="_tcp"
    SRV_DOMAIN="example.com"
fi

echo "Checking if CNAME record exists in Cloudflare..."
if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
    cname_record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=CNAME&name=$CLOUDFLARE_CNAME_RECORD_NAME" \
        -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json")
elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
    cname_record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=CNAME&name=$CLOUDFLARE_CNAME_RECORD_NAME" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
else
    echo "No valid Cloudflare authentication method detected. Cannot fetch CNAME record."
    exit 1
fi

echo "CNAME lookup response: $cname_record_response"

cname_record_exists=false
cname_record_id=""

if [[ $cname_record_response == *"\"count\":0"* ]]; then
    echo "CNAME record does not exist in Cloudflare. Creating it now..."
    
    if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
        create_cname_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
            -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"example.com\",\"ttl\":1,\"proxied\":false}")
    elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
        create_cname_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"example.com\",\"ttl\":1,\"proxied\":false}")
    fi
    
    echo "CNAME creation response: $create_cname_response"
    
    if [[ $create_cname_response == *"\"success\":true"* ]]; then
        echo "CNAME record created successfully!"
        cname_record_exists=true
        cname_record_id=$(echo "$create_cname_response" | sed -E 's/.*"id":"([^"]+)".*/\1/')
        echo "Created CNAME record ID: $cname_record_id"
    else
        echo "Failed to create CNAME record. Exiting."
        exit 1
    fi
else
    cname_record_exists=true
    cname_record_id=$(echo "$cname_record_response" | sed -E 's/.*"id":"([^"]+)".*/\1/')
    echo "Found CNAME record ID: $cname_record_id"
fi

srv_record_exists=false
srv_record_id=""

if [ -n "$CLOUDFLARE_SRV_RECORD" ] && [ "$CLOUDFLARE_SRV_RECORD" != "_minecraft._tcp.example.com" ]; then
    echo "Checking if SRV record exists in Cloudflare..."
    echo "Looking up SRV record with name: $CLOUDFLARE_SRV_RECORD"
    
    if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
        srv_record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=SRV&name=$CLOUDFLARE_SRV_RECORD" \
            -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json")
    elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
        srv_record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=SRV&name=$CLOUDFLARE_SRV_RECORD" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json")
    fi
    
    echo "SRV lookup response: $srv_record_response"

    if [[ $srv_record_response == *"\"count\":0"* ]]; then
        echo "SRV record does not exist in Cloudflare. Creating it now..."
        
        if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
            create_srv_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
                -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
                -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"SRV\",\"name\":\"$CLOUDFLARE_SRV_RECORD\",\"data\":{\"service\":\"$SRV_SERVICE\",\"proto\":\"$SRV_PROTO\",\"name\":\"$SRV_DOMAIN\",\"priority\":1,\"weight\":1,\"port\":25565,\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")
        elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
            create_srv_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"SRV\",\"name\":\"$CLOUDFLARE_SRV_RECORD\",\"data\":{\"service\":\"$SRV_SERVICE\",\"proto\":\"$SRV_PROTO\",\"name\":\"$SRV_DOMAIN\",\"priority\":1,\"weight\":1,\"port\":25565,\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")
        fi
        
        echo "SRV creation response: $create_srv_response"
        
        if [[ $create_srv_response == *"\"success\":true"* ]]; then
            echo "SRV record created successfully!"
            srv_record_exists=true
            srv_record_id=$(echo "$create_srv_response" | sed -E 's/.*"id":"([^"]+)".*/\1/')
            echo "Created SRV record ID: $srv_record_id"
        else
            echo "Failed to create SRV record. Continuing without SRV record."
        fi
    else
        srv_record_exists=true
        srv_record_id=$(echo "$srv_record_response" | sed -E 's/.*"id":"([^"]+)".*/\1/')
        echo "Found SRV record ID: $srv_record_id"
    fi
fi

echo "Starting ngrok..."
ngrok config add-authtoken $NGROK_AUTH_TOKEN

echo "Running: ngrok tcp $TARGET_HOST:$NGROK_TCP_PORT"
ngrok tcp $TARGET_HOST:$NGROK_TCP_PORT >/dev/null &

echo "Waiting for ngrok tunnel to be established..."
for i in {1..30}; do
    if curl -s localhost:4040/api/tunnels | grep -q "tcp://"; then
        break
    fi
    echo "Waiting for ngrok tunnel... ($i/30)"
    sleep 2
done

ngrok_info=$(curl -s localhost:4040/api/tunnels)
echo "Ngrok tunnel info: $ngrok_info"

if ! echo "$ngrok_info" | grep -q "tcp://"; then
    echo "Failed to establish ngrok tunnel. Exiting."
    exit 1
fi

ngrok_url=$(echo "$ngrok_info" | grep -o "tcp://[0-9a-z.-]*:[0-9]*")
parsed_ngrok_url=${ngrok_url/tcp:\/\//}

IFS=':' read -ra ADDR <<<"$parsed_ngrok_url"

ngrok_host=${ADDR[0]}
ngrok_port=${ADDR[1]}

echo "Ngrok Host is $ngrok_host"
echo "Ngrok Port is $ngrok_port"

if [ "$cname_record_exists" = true ]; then
    echo "Updating CNAME record in Cloudflare..."
    if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
        update_cname_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$cname_record_id" \
            -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"$ngrok_host\"}")
    elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
        update_cname_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$cname_record_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$CLOUDFLARE_CNAME_RECORD_NAME\",\"content\":\"$ngrok_host\"}")
    fi

    echo "CNAME update response: $update_cname_response"

    if [[ $update_cname_response == *"\"success\":true"* ]]; then
        echo "CNAME record successfully updated in Cloudflare!"
    else
        echo "CNAME record could not be updated in Cloudflare. $update_cname_response"
    fi
fi

if [ "$srv_record_exists" = true ]; then
    echo "Updating SRV record in Cloudflare..."
    
    echo "Using service: $SRV_SERVICE, proto: $SRV_PROTO for SRV record"
    
    if [ "$CLOUDFLARE_AUTH_METHOD" = "API_KEY" ]; then
        update_srv_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$srv_record_id" \
            -H "X-Auth-Email: $CLOUDFLARE_AUTH_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"SRV\",\"name\":\"$CLOUDFLARE_SRV_RECORD\",\"data\": {\"service\":\"$SRV_SERVICE\",\"proto\":\"$SRV_PROTO\",\"name\":\"$SRV_DOMAIN\",\"priority\":1,\"weight\":1,\"port\":$ngrok_port,\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")
    elif [ "$CLOUDFLARE_AUTH_METHOD" = "API_TOKEN" ]; then
        update_srv_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$srv_record_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"SRV\",\"name\":\"$CLOUDFLARE_SRV_RECORD\",\"data\": {\"service\":\"$SRV_SERVICE\",\"proto\":\"$SRV_PROTO\",\"name\":\"$SRV_DOMAIN\",\"priority\":1,\"weight\":1,\"port\":$ngrok_port,\"target\":\"$CLOUDFLARE_CNAME_RECORD_NAME\"}}")
    fi

    echo "SRV update response: $update_srv_response"

    if [[ $update_srv_response == *"\"success\":true"* ]]; then
        echo "SRV record successfully updated in Cloudflare!"
    else
        echo "SRV record could not be updated in Cloudflare. $update_srv_response"
    fi
fi

echo "Done! You can connect to your server using $ngrok_host:$ngrok_port"
echo "CNAME record: $CLOUDFLARE_CNAME_RECORD_NAME -> $ngrok_host"
if [ "$srv_record_exists" = true ]; then
    echo "SRV record: $CLOUDFLARE_SRV_RECORD -> $CLOUDFLARE_CNAME_RECORD_NAME:$ngrok_port"
fi

tail -f "/dev/null"

exit 0
