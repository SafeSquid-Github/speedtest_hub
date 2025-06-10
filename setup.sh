#!/bin/bash

# This script deploys LibreSpeed and OpenSpeedTest with an Apache2 web server.
# It configures PHP, sets up a custom directory structure, and configures
# LibreSpeed's telemetry to use a custom database path.
# It must be run with root privileges (e.g., using sudo).

# --- Configuration ---
WEB_ROOT="/var/www"
HTML_DIR="${WEB_ROOT}/html"
LIBRESPEED_DIR="${HTML_DIR}/librespeed"
OPENSPEED_DIR="${HTML_DIR}/openspeedtest"
LS_DB_DIR="${WEB_ROOT}/ls_db"
LS_DB_FILE="${LS_DB_DIR}/speedtest_results.sql"

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
# Install Apache, PHP, required modules (including gd), git, unzip, and tree
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
echo "Applying new PHP settings..."
sed -i 's/^\s*post_max_size\s*=\s*.*/post_max_size = 0/' "$PHP_INI_PATH"
sed -i 's/^\s*;extension=gd/extension=gd/' "$PHP_INI_PATH"
sed -i 's/^\s*;extension=pdo_sqlite/extension=pdo_sqlite/' "$PHP_INI_PATH"

echo "### PHP configuration updated successfully. ###"


# 4. Create Directory Structure and Set Permissions
# -----------------------------------------------------------------------------
echo "### 4. Setting up the required directory structure... ###"

# Stop Apache to safely modify its directories
systemctl stop apache2

# Clean up default installations in the web root to ensure a fresh start
rm -rf "${HTML_DIR:?}"/*

# Create the specific directory structure requested
mkdir -p "$LIBRESPEED_DIR"
mkdir -p "$OPENSPEED_DIR"
mkdir -p "$LS_DB_DIR"

# Set ownership on the database directory so the web server can write to it
chown www-data:www-data "$LS_DB_DIR"

echo "### Directory structure created at ${WEB_ROOT} ###"


# 5. Deploy LibreSpeed and Configure Telemetry
# -----------------------------------------------------------------------------
echo "### 5. Downloading and deploying LibreSpeed... ###"

# Clone the official LibreSpeed repository to a temporary location
git clone https://github.com/librespeed/speedtest.git /tmp/librespeed_temp

# Copy the application files to the target directory
rsync -a --exclude='.git' --exclude='CNAME' --exclude='README.md' /tmp/librespeed_temp/ "$LIBRESPEED_DIR/"

# --- Configure LibreSpeed Telemetry ---
TELEMETRY_SETTINGS_FILE="${LIBRESPEED_DIR}/results/telemetry_settings.php"
echo "Configuring LibreSpeed telemetry database path..."

# Use sed to replace the default SQLite file path with the custom one.
# We use '#' as a delimiter because the path contains '/'.
sed -i "s#^\$Sqlite_db_file\s*=\s*.*#\$Sqlite_db_file = '${LS_DB_FILE}';#" "$TELEMETRY_SETTINGS_FILE"

echo "Telemetry settings updated in $TELEMETRY_SETTINGS_FILE"
# --- End Telemetry Configuration ---

# Download the GeoIP PHP archive needed for location detection
echo "Downloading GeoIP2 library..."
wget -q -O "$LIBRESPEED_DIR/backend/geoip2.phar" https://github.com/maxmind/GeoIP2-php/releases/latest/download/geoip2.phar

# Create placeholder files
echo "Creating placeholder for GeoLite2 DB. Manual download with license key is required for GeoIP."
touch "$LIBRESPEED_DIR/backend/country_asn.mmdb"
touch "$LS_DB_FILE" # Create the empty database file

# Set ownership for LibreSpeed folders and the new database file
chown -R www-data:www-data "$LIBRESPEED_DIR/results"
chown -R www-data:www-data "$LIBRESPEED_DIR/backend"
chown www-data:www-data "$LS_DB_FILE"

echo "### LibreSpeed deployed and configured. ###"


# 6. Deploy OpenSpeedTest
# -----------------------------------------------------------------------------
echo "### 6. Downloading and deploying OpenSpeedTest... ###"

# Download the latest self-hosted version from GitHub
wget -q -O /tmp/openspeedtest.zip https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip

# Unzip to a temporary location
unzip -q /tmp/openspeedtest.zip -d /tmp/

# Move the contents into the target directory
rsync -a /tmp/Speed-Test-main/ "$OPENSPEED_DIR/"

echo "### OpenSpeedTest deployed to $OPENSPEED_DIR ###"


# 7. Finalize and Clean Up
# -----------------------------------------------------------------------------
echo "### 7. Finalizing installation and cleaning up... ###"

# Clean up temporary files
rm -rf /tmp/librespeed_temp
rm -f /tmp/openspeedtest.zip
rm -rf /tmp/Speed-Test-main

# Enable and restart Apache to serve the new files and load new PHP settings
echo "Enabling and restarting Apache2..."
systemctl enable apache2
systemctl start apache2

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
echo "PHP configuration has been updated at: $PHP_INI_PATH"
echo "LibreSpeed telemetry is configured to save results to:"
echo "  ${LS_DB_FILE}"
echo ""
echo "NOTE: For LibreSpeed's GeoIP feature to work, you must manually"
echo "      download the GeoLite2-Country.mmdb database from MaxMind"
echo "      (requires a free account) and place it in:"
echo "      ${LIBRESPEED_DIR}/backend/"
echo "================================================================="

exit 0