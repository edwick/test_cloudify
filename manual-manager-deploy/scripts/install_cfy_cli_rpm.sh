#!/usr/bin/env bash
# Assumes user has sudo privileges

set -e

# NOTE: The Cloudify Magic we are engaging in means we want to run everything on the VM we
# are provisioning rather than inside the Cloudify agent's virtualenv.
# This is NOT something you should do in a normal script plugin.
#deactivate

cd /tmp
mkdir -p tools_install ; cd tools_install
curl -L -O https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install wagon

curl -L $(ctx node properties cloudify_cli_rpm_url) -o cloudify-installer.rpm
sudo rpm -i ./cloudify-installer.rpm
