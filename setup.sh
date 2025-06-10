#!/bin/bash

# This script deploys LibreSpeed and OpenSpeedTest, configures PHP,
# and copies a separate landing page file to the web root.
# It must be run with root privileges (e.g., using sudo).

# --- Configuration ---
WEB_ROOT="/var/www"
HTML_DIR="${WEB_ROOT}/html"
LIBRESPEED_DIR="${HTML_DIR}/librespeed"
OPENSPEED_DIR="${HTML_DIR}/openspeedtest"
LS_DB_DIR="${WEB_ROOT}/ls_db"
LANDING_PAGE_SOURCE="./landing_page.php"

# --- Script Start ---

# 1. Sanity Checks and Preparation
# -----------------------------------------------------------------------------
echo "### 1. Starting Sanity Checks and Preparation ###"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo." 
   exit 1
fi

# Check if the landing page file exists in the current directory
if [ ! -f "$LANDING_PAGE_SOURCE" ]; then
    echo "Error: Landing page file not found!"
    echo "Please ensure 'landing_page.php' is in the same directory as this script."
    exit 1
fi

# Exit immediately if a command exits with a non-zero status.
set -e

# 2. Install Dependencies
# -----------------------------------------------------------------------------
echo "### 2. Updating system and installing dependencies... ###"
apt-get update
# Install Apache, PHP, required modules, git, unzip, and tree
apt-get install -y apache2 php libapache2-mod-php php-sqlite3 php-xml php-curl php-gd git unzip wget tree

echo "### Dependencies installed successfully. ###"


# 3. Configure PHP (php.ini)
# -----------------------------------------------------------------------------
echo "### 3. Configuring php.ini... ###"

# Find the php.ini file used by Apache
PHP_INI_PATH=$(find /etc/php -name php.ini -path '*/apache2/*')

if [[ -z "$PHP_INI_PATH" ]] || [[ ! -f "$PHP_INI_PATH" ]]; then
    echo "Error: Could not find the Apache php.ini file. Exiting."
    exit 1
fi

echo "Found Apache php.ini at: $PHP_INI_PATH"

# Create a backup of the original php.ini file
cp "$PHP_INI_PATH" "${PHP_INI_PATH}.bak"
echo "Backup of original php.ini created at ${PHP_INI_PATH}.bak"

# Update settings using sed
sed -i 's/^\s*post_max_size\s*=\s*.*/post_max_size = 0/' "$PHP_INI_PATH"
sed -i 's/^\s*;extension=gd/extension=gd/' "$PHP_INI_PATH"
sed -i 's/^\s*;extension=pdo_sqlite/extension=pdo_sqlite/' "$PHP_INI_PATH"

echo "### PHP configuration updated successfully. ###"


# 4. Create Directory Structure and Set Permissions
# -----------------------------------------------------------------------------
echo "### 4. Setting up the required directory structure... ###"

systemctl stop apache2
# Clean up default installations in the web root.
rm -rf "${HTML_DIR:?}"/*
mkdir -p "$LIBRESPEED_DIR"
mkdir -p "$OPENSPEED_DIR"
mkdir -p "$LS_DB_DIR"
echo "### Directory structure created at ${WEB_ROOT} ###"


# 5. Deploy LibreSpeed
# -----------------------------------------------------------------------------
echo "### 5. Downloading and deploying LibreSpeed... ###"
git clone https://github.com/librespeed/speedtest.git /tmp/librespeed_temp
rsync -a --exclude='.git' --exclude='CNAME' --exclude='README.md' /tmp/librespeed_temp/ "$LIBRESPEED_DIR/"
wget -q -O "$LIBRESPEED_DIR/backend/geoip2.phar" https://github.com/maxmind/GeoIP2-php/releases/latest/download/geoip2.phar
touch "$LIBRESPEED_DIR/backend/country_asn.mmdb"
touch "$LS_DB_DIR/speedtest_results.sql"
chown -R www-data:www-data "$LIBRESPEED_DIR/results" "$LIBRESPEED_DIR/backend"
echo "### LibreSpeed deployed to $LIBRESPEED_DIR ###"


# 6. Deploy OpenSpeedTest
# -----------------------------------------------------------------------------
echo "### 6. Downloading and deploying OpenSpeedTest... ###"
wget -q -O /tmp/openspeedtest.zip https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip
unzip -q /tmp/openspeedtest.zip -d /tmp/
rsync -a /tmp/Speed-Test-main/ "$OPENSPEED_DIR/"
# Copy the favicon to the root of the app's folder for our landing page to find
cp "$OPENSPEED_DIR/assets/images/icons/favicon.ico" "$OPENSPEED_DIR/favicon.ico"
echo "### OpenSpeedTest deployed to $OPENSPEED_DIR ###"


# 7. Deploy Dynamic Landing Page
# -----------------------------------------------------------------------------
echo "### 7. Deploying dynamic PHP landing page... ###"
cp "$LANDING_PAGE_SOURCE" "${HTML_DIR}/index.php"
chown www-data:www-data "${HTML_DIR}/index.php"
echo "### Landing page copied to ${HTML_DIR}/index.php ###"


# 8. Finalize and Clean Up
# -----------------------------------------------------------------------------
echo "### 8. Finalizing installation and cleaning up... ###"

# Clean up temporary files
rm -rf /tmp/librespeed_temp
rm -f /tmp/openspeedtest.zip
rm -rf /tmp/Speed-Test-main

# Enable and restart Apache to serve the new files and load new PHP settings
echo "Enabling and restarting Apache2..."
systemctl enable apache2
systemctl start apache2

# 9. Verification and Summary
# -----------------------------------------------------------------------------
echo "### 9. Deployment Complete! ###"

# Get server IP for easy access
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "================================================================="
echo "  Deployment Successful!"
echo "================================================================="
echo ""
echo "A dynamic landing page has been created. Visit the root URL to begin:"
echo ""
echo "  >>> http://${SERVER_IP}/ <<<"
echo ""
echo "From there, you can select which speed test to use."
echo ""
echo "PHP configuration was updated at: $PHP_INI_PATH"
echo "================================================================="

exit 0