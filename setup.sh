#!/bin/bash

# This script deploys LibreSpeed and OpenSpeedTest with an Apache2 web server.
# It must be run with root privileges (e.g., using sudo).

# --- Configuration ---
WEB_ROOT="/var/www"
HTML_DIR="${WEB_ROOT}/html"
LIBRESPEED_DIR="${HTML_DIR}/librespeed"
OPENSPEED_DIR="${HTML_DIR}/openspeedtest"
LS_DB_DIR="${WEB_ROOT}/ls_db"

# --- Script Start ---

# 1. Sanity Checks and Preparation
# -----------------------------------------------------------------------------
echo "### 1. Starting Sanity Checks and Preparation ###"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo." 
   exit 1
fi

# Exit immediately if a command exits with a non-zero status.
set -e

# 2. Install Dependencies
# -----------------------------------------------------------------------------
echo "### 2. Updating system and installing dependencies... ###"
apt-get update
# Install Apache, PHP and required modules, git for cloning, unzip for archives, and tree for final verification
apt-get install -y apache2 php libapache2-mod-php php-sqlite3 php-xml php-curl git unzip wget tree

echo "### Dependencies installed successfully. ###"


# 3. Create Directory Structure and Set Permissions
# -----------------------------------------------------------------------------
echo "### 3. Setting up the required directory structure... ###"

# Stop Apache to safely modify its directories
systemctl stop apache2

# Clean up default installations in the web root to ensure a fresh start
rm -rf "${HTML_DIR:?}"/*

# Create the specific directory structure requested
mkdir -p "$LIBRESPEED_DIR"
mkdir -p "$OPENSPEED_DIR"
mkdir -p "$LS_DB_DIR"

echo "### Directory structure created at ${WEB_ROOT} ###"


# 4. Deploy LibreSpeed
# -----------------------------------------------------------------------------
echo "### 4. Downloading and deploying LibreSpeed... ###"

# Clone the official LibreSpeed repository to a temporary location
git clone https://github.com/librespeed/speedtest.git /tmp/librespeed_temp

# Copy the application files to the target directory
# Using rsync is a good way to copy contents and exclude the .git folder
rsync -a --exclude='.git' --exclude='CNAME' --exclude='README.md' /tmp/librespeed_temp/ "$LIBRESPEED_DIR/"

# Download the GeoIP PHP archive needed for location detection
echo "Downloading GeoIP2 library..."
wget -q -O "$LIBRESPEED_DIR/backend/geoip2.phar" https://github.com/maxmind/GeoIP2-php/releases/latest/download/geoip2.phar

# NOTE on MaxMind GeoLite2 Database:
# MaxMind now requires a free license key to download the GeoLite2 database.
# This script will create a placeholder file as requested in the tree structure.
# To enable GeoIP functionality, sign up at https://www.maxmind.com, get a key,
# and download the GeoLite2-Country.mmdb file into the backend folder.
echo "Creating placeholder for GeoLite2 DB. Manual download with license key is required for GeoIP."
touch "$LIBRESPEED_DIR/backend/country_asn.mmdb"

# Create the empty placeholder SQL file as requested in the tree structure
touch "$LS_DB_DIR/speedtest_results.sql"

# LibreSpeed's telemetry needs to write to the 'results' and 'backend' directories.
# Set ownership to the Apache user (www-data on Debian/Ubuntu).
chown -R www-data:www-data "$LIBRESPEED_DIR/results"
chown -R www-data:www-data "$LIBRESPEED_DIR/backend"

echo "### LibreSpeed deployed to $LIBRESPEED_DIR ###"


# 5. Deploy OpenSpeedTest
# -----------------------------------------------------------------------------
echo "### 5. Downloading and deploying OpenSpeedTest... ###"

# Download the latest self-hosted version from GitHub
wget -q -O /tmp/openspeedtest.zip https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip

# Unzip to a temporary location
unzip -q /tmp/openspeedtest.zip -d /tmp/

# Move the contents into the target directory
# The archive extracts to a folder named "Speed-Test-main"
rsync -a /tmp/Speed-Test-main/ "$OPENSPEED_DIR/"

echo "### OpenSpeedTest deployed to $OPENSPEED_DIR ###"


# 6. Finalize and Clean Up
# -----------------------------------------------------------------------------
echo "### 6. Finalizing installation and cleaning up... ###"

# Clean up temporary files
rm -rf /tmp/librespeed_temp
rm -f /tmp/openspeedtest.zip
rm -rf /tmp/Speed-Test-main

# Enable and restart Apache to serve the new files
echo "Enabling and restarting Apache2..."
systemctl enable apache2
systemctl start apache2

# 7. Verification and Summary
# -----------------------------------------------------------------------------
echo "### 7. Deployment Complete! Verifying structure... ###"

# Display the final directory tree
tree -af "$WEB_ROOT"

# Get server IP for easy access
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "================================================================="
echo "  Deployment Successful!"
echo "================================================================="
echo ""
echo "You can now access your speed test instances:"
echo ""
echo "  - LibreSpeed:    http://${SERVER_IP}/librespeed/"
echo "  - OpenSpeedTest: http://${SERVER_IP}/openspeedtest/"
echo ""
echo "NOTE: For LibreSpeed's GeoIP feature to work, you must manually"
echo "      download the GeoLite2-Country.mmdb database from MaxMind"
echo "      (requires a free account) and place it in:"
echo "      ${LIBRESPEED_DIR}/backend/"
echo "================================================================="

exit 0