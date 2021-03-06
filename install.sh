#!/bin/bash
#
# Can be run for updates too.

err_report() {
    echo "[ERROR] on line $1"
    exit 1
}

trap 'err_report $LINENO' ERR

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Check Python version
echo "[INFO] Checking Python version..."
PYTHON_VERSION=$(python --version | awk '{ print $NF }')
REQUIRED_VERSION="3.8.5"
if [[ $PYTHON_VERSION != $REQUIRED_VERSION ]]; then
    min=$(echo $PYTHON_VERSION $REQUIRED_VERSION| awk '{if ($1 < $2) print $1; else print $2}')
    if [[ "$min" == "$PYTHON_VERSION" ]]; then
        echo "[ERROR] Please install Python 3.8.5 or higher."
        exit 1
    fi
fi

# Get latest code
echo "[INFO] Retrieve app updates"
git pull | sed -e 's/^/[INFO] /g'

echo "[INFO] Installing apt-get packages..."
sudo apt-get -y -qq install python-usb mpg123

echo "[INFO] Installing Python packages..."
pip install -q -r requirements.txt

if [ ! -f /etc/udev/rules.d/99-lego.rules ]; then
    echo "[INFO] Install USB device rules..."
    sudo cp ${DIR}/99-lego.rules /etc/udev/rules.d
    sudo udevadm control --reload-rules && sudo udevadm trigger
fi

if [ ! -f ${DIR}/tags.yml ]; then
    echo "[INFO] Initial example tags.yml created. Edit this file as tag UIDs are discovered." 
    cp ${DIR}/tags.yml-sample ${DIR}/tags.yml
fi
if [ ! -f ${DIR}/config.py ]; then
    echo "[OPTIONAL] Edit the config.py with your Spotify API app credentials before starting."
    cp ${DIR}/config.py-sample ${DIR}/config.py
fi

# Install startup service
PYTHON_PATH=$(which python)
MUSICFIG_DIR=$(pwd)
cp musicfig.service musicfig.service-temp
sed -i "s!%MUSICFIG_DIR%!${MUSICFIG_DIR}!ig" musicfig.service-temp
sed -i "s!%PYTHON_PATH%!${PYTHON_PATH}!ig" musicfig.service-temp
sudo cp musicfig.service-temp /etc/systemd/system/musicfig.service
rm -f musicfig.service-temp
sudo chown root:root /etc/systemd/system/musicfig.service
sudo chmod 644 /etc/systemd/system/musicfig.service
sudo systemctl daemon-reload
sudo systemctl enable musicfig.service
echo "[INFO] Starting Musicfig server"
sudo systemctl restart musicfig.service
echo "[INFO] See the musicfig.log file for application logs."
