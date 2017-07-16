#!/usr/bin/env bash
# Assumes user has sudo privileges

set -e

cd /tmp
mkdir -p tools_install ; cd tools_install
curl -L $(ctx node properties cloudify_cli_rpm_url) -o cloudify-installer.rpm
sudo rpm -i ./cloudify-installer.rpm

which python > pythonpath
