#!/usr/bin/env bash
# Assumes user has sudo privileges

set -e

cd /tmp
mkdir -p tools_install ; cd tools_install
curl -L -O https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install virtualenv
# Install cloudify globally while we're here
# TODO: This does not seem to work because the virtualenv is goofy. seems to be side effect of
# cloudify agent or something.
CLI_VERSION=$(ctx node properties cloudify_cli_version)
sudo pip install cloudify==${CLI_VERSION}
sudo pip install wagon
