#!/bin/bash

# This script is used to create docker image and run the container
# It's main purpose is to download the latest ncfs.sh script from github
# and run it inside the container
# Nothing fancy. Just a simple script to get the latest ncfs.sh script

# Get the latest ncfs.sh script from github
wget https://raw.githubusercontent.com/barbarbar338/ncfs/master/ncfs.sh

# Set permissions
chmod +x ncfs.sh

# Run the ncfs.sh script
bash ncfs.sh

