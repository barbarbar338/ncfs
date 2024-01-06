# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# Exporting variables from here. 
# Instead of using jq in every script, 
# we can just source this file

# Usage: get_variable "variable_name" "config_file" "force"
# Example: get_variable "NGROK_TCP_PORT" "config.json" true
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

# read config from config.json or env variables
export NGROK_AUTH_TOKEN=$(get_variable "NGROK_AUTH_TOKEN" "config.json" true)
export NGROK_TCP_PORT=$(get_variable "NGROK_TCP_PORT" "config.json" true)
export CLOUDFLARE_AUTH_EMAIL=$(get_variable "CLOUDFLARE_AUTH_EMAIL" "config.json" true)
export CLOUDFLARE_API_KEY=$(get_variable "CLOUDFLARE_API_KEY" "config.json" true)
export CLOUDFLARE_ZONE_ID=$(get_variable "CLOUDFLARE_ZONE_ID" "config.json" true)
export CLOUDFLARE_CNAME_RECORD_NAME=$(get_variable "CLOUDFLARE_CNAME_RECORD_NAME" "config.json" true)
export CLOUDFLARE_SRV_RECORD_NAME=$(get_variable "CLOUDFLARE_SRV_RECORD_NAME" "config.json" false)
