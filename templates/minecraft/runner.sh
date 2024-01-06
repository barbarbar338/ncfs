#!/bin/bash

# Copyright © 2023 Barış DEMİRCİ <hi@338.rocks>
# SPDX-License-Identifier: GPL-3.0

# This script is used to create docker image and run the container
# It's main purpose is to download the latest ncfs.sh script from github
# and run it inside the container
# Nothing fancy. Just a simple script to get the latest ncfs.sh script

# Get the latest ncfs.sh script from github
wget https://raw.githubusercontent.com/barbarbar338/ncfs/master/templates/minecraft/ncfs.sh
wget https://raw.githubusercontent.com/barbarbar338/ncfs/master/shared/getconfig.sh
wget https://raw.githubusercontent.com/barbarbar338/ncfs/master/shared/cf.sh
wget https://raw.githubusercontent.com/barbarbar338/ncfs/master/shared/ngrok.sh

# Set permissions
chmod +x ncfs.sh

# Run the ncfs.sh script
bash ncfs.sh
