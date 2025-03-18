#!/bin/bash

# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# This script is used to run the ncfs.sh script which is packaged with the container
# Simple script to execute the ncfs.sh in the container

echo "Starting runner script..."
echo "Using packaged ncfs.sh script"

# Run the ncfs.sh script
bash /app/ncfs.sh
