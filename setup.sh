#!/bin/bash

# This script deploys LibreSpeed and OpenSpeedTest, configures PHP,
# and copies a separate landing page file to the web root.
# It uses functions for modularity and must be run with root privileges.
#
# Style Guide:
# - Functions are in UPPERCASE_SNAKE_CASE.
# - All variable expansions use the ${VARIABLE} syntax.

# --- Configuration (Global Variables) ---
WEB_ROOT="/var/www"
HTML_DIR="${WEB_ROOT}/html"
LIBRESPEED_DIR="${HTML_DIR}/librespeed"
OPENSPEED_DIR="${HTML_DIR}/openspeedtest"
LS_DB_DIR="${WEB_ROOT}/ls_db"
LANDING_PAGE_SOURCE_NAME="index.php" # Name of the source file
LANDING_PAGE_SOURCE_PATH="./${LANDING_PAGE_SOURCE_NAME}" # Path relative to script

# --- Function Definitions ---

# 1. Sanity Checks and Preparation
# -----------------------------------------------------------------------------
CHECK_ROOT() {
    echo "### 1.1. Checking root privileges... ###"
    if [[ ${EUID} -ne 0 ]]; then
       echo "Error: This script must be run as root. Please use sudo." 
       exit 1
    fi
    echo "Root privileges: OK."
}

CHECK_LANDING_PAGE_FILE() {
    echo "### 1.2. Checking for landing page source file... ###"
    if [ ! -f "${LANDING_PAGE_SOURCE_PATH}" ]; then
        echo "Error: Landing page file not found!"
        echo "Please ensure '${LANDING_PAGE_SOURCE_NAME}' is in the same directory as this script."
        exit 1
    fi
    echo "Landing page source file ('${LANDING_PAGE_SOURCE_NAME}') found."
}

# 2. Install Dependencies
# -----------------------------------------------------------------------------
INSTALL_DEPENDENCIES() {
    echo "### 2. Updating system and installing dependencies... ###"
    apt-get update
    apt-get install -y apache2 php libapache2-mod-php php-sqlite3 php-xml php-curl php-gd git unzip wget tree
    echo "### Dependencies installed successfully. ###"
}

# 3. Configure PHP (php.ini)
# -----------------------------------------------------------------------------
CONFIGURE_PHP() {
    echo "### 3. Configuring php.ini... ###"
    local PHP_INI_PATH
    PHP_INI_PATH=$(find /etc/php -name php.ini -path '*/apache2/*')

    if [[ -z "${PHP_INI_PATH}" ]] || [[ ! -f "${PHP_INI_PATH}" ]]; then
        echo "Error: Could not find the Apache php.ini file. Exiting."
        exit 1
    fi
    echo "Found Apache php.ini at: ${PHP_INI_PATH}"

    cp "${PHP_INI_PATH}" "${PHP_INI_PATH}.bak"
    echo "Backup of original php.ini created at ${PHP_INI_PATH}.bak"

    sed -i 's/^\s*post_max_size\s*=\s*.*/post_max_size = 0/' "${PHP_INI_PATH}"
    sed -i 's/^\s*;extension=gd/extension=gd/' "${PHP_INI_PATH}"
    sed -i 's/^\s*;extension=pdo_sqlite/extension=pdo_sqlite/' "${PHP_INI_PATH}"

    echo "### PHP configuration updated successfully. ###"
    # Store the path in a global-like variable for the summary function
    _PHP_INI_CONFIGURED_PATH="${PHP_INI_PATH}"
}

# 4. Create Directory Structure
# -----------------------------------------------------------------------------
SETUP_DIRECTORIES() {
    echo "### 4. Setting up the required directory structure... ###"
    echo "Stopping Apache to safely modify its directories..."
    systemctl stop apache2

    echo "Cleaning up default installations in ${HTML_DIR}..."
    rm -rf "${HTML_DIR:?}"/* # :? ensures the variable is set, preventing 'rm -rf /*'

    echo "Creating application directories..."
    mkdir -p "${LIBRESPEED_DIR}"
    mkdir -p "${OPENSPEED_DIR}"
    mkdir -p "${LS_DB_DIR}"
    echo "### Directory structure created at ${WEB_ROOT} ###"
}

# 5. Deploy LibreSpeed
# -----------------------------------------------------------------------------
DEPLOY_LIBRESPEED() {
    echo "### 5. Downloading and deploying LibreSpeed... ###"
    local temp_dir="/tmp/librespeed_temp"
    
    git clone https://github.com/librespeed/speedtest.git "${temp_dir}"
    rsync -a --exclude='.git' --exclude='CNAME' --exclude='README.md' "${temp_dir}/" "${LIBRESPEED_DIR}/"
    
    echo "Downloading GeoIP2 library..."
    wget -q -O "${LIBRESPEED_DIR}/backend/geoip2.phar" https://github.com/maxmind/GeoIP2-php/releases/latest/download/geoip2.phar
    
    echo "Creating placeholder for GeoLite2 DB (manual download required)."
    touch "${LIBRESPEED_DIR}/backend/country_asn.mmdb"
    
    echo "Creating placeholder for LibreSpeed results DB."
    touch "${LS_DB_DIR}/speedtest_results.sql"
    
    echo "Setting permissions for LibreSpeed..."
    chown -R www-data:www-data "${LIBRESPEED_DIR}/results" "${LIBRESPEED_DIR}/backend"
    
    rm -rf "${temp_dir}" # Clean up temp dir for this app
    echo "### LibreSpeed deployed to ${LIBRESPEED_DIR} ###"
}

# 6. Deploy OpenSpeedTest
# -----------------------------------------------------------------------------
DEPLOY_OPENSPEEDTEST() {
    echo "### 6. Downloading and deploying OpenSpeedTest... ###"
    local temp_zip="/tmp/openspeedtest.zip"
    local temp_extract_dir="/tmp/openspeedtest_extract"
    local extracted_app_dir_name="Speed-Test-main" # Common name for GitHub main branch zips

    wget -q -O "${temp_zip}" https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip
    
    mkdir -p "${temp_extract_dir}"
    unzip -q "${temp_zip}" -d "${temp_extract_dir}"
    
    rsync -a "${temp_extract_dir}/${extracted_app_dir_name}/" "${OPENSPEED_DIR}/"
    
    echo "Copying OpenSpeedTest favicon for landing page..."
    cp "${OPENSPEED_DIR}/assets/images/icons/favicon.ico" "${OPENSPEED_DIR}/favicon.ico"
    
    rm -f "${temp_zip}"
    rm -rf "${temp_extract_dir}"
    echo "### OpenSpeedTest deployed to ${OPENSPEED_DIR} ###"
}

# 7. Deploy Dynamic Landing Page
# -----------------------------------------------------------------------------
DEPLOY_LANDING_PAGE() {
    echo "### 7. Deploying dynamic PHP landing page... ###"
    cp "${LANDING_PAGE_SOURCE_PATH}" "${HTML_DIR}/index.php"
    chown www-data:www-data "${HTML_DIR}/index.php"
    echo "### Landing page copied to ${HTML_DIR}/index.php ###"
}

# 8. Finalize and Clean Up
# -----------------------------------------------------------------------------
FINALIZE_SETUP() {
    echo "### 8. Finalizing installation... ###"
    echo "Enabling and restarting Apache2..."
    systemctl enable apache2
    systemctl start apache2
    echo "### Apache2 restarted and enabled. ###"
}

# 9. Verification and Summary
# -----------------------------------------------------------------------------
SHOW_SUMMARY() {
    echo "### 9. Deployment Complete! Verifying structure... ###"
    tree -afL 2 "${WEB_ROOT}" # Limit depth for a cleaner summary

    local SERVER_IP
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
    echo "From there, you can select which speed test to use:"
    echo "  - LibreSpeed:    http://${SERVER_IP}/librespeed/"
    echo "  - OpenSpeedTest: http://${SERVER_IP}/openspeedtest/"
    echo ""
    echo "PHP configuration was updated at: ${_PHP_INI_CONFIGURED_PATH}"
    echo "NOTE: For LibreSpeed's GeoIP feature to work, you must manually"
    echo "      download the GeoLite2-Country.mmdb database from MaxMind"
    echo "      (requires a free account) and place it in:"
    echo "      ${LIBRESPEED_DIR}/backend/"
    echo "================================================================="
}

# --- Main Execution ---
MAIN() {
    # Exit immediately if a command exits with a non-zero status.
    set -e 

    echo "Starting Speed Test Deployment Script..."
    echo "----------------------------------------"

    CHECK_ROOT
    CHECK_LANDING_PAGE_FILE
    
    INSTALL_DEPENDENCIES
    CONFIGURE_PHP
    
    SETUP_DIRECTORIES
    
    DEPLOY_LIBRESPEED
    DEPLOY_OPENSPEEDTEST
    
    DEPLOY_LANDING_PAGE
    
    FINALIZE_SETUP
    SHOW_SUMMARY

    echo "----------------------------------------"
    echo "Script execution finished."
}

# Run the main function, passing all script arguments to it
MAIN "${@}"