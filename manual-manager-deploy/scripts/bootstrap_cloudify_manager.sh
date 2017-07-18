#!/usr/bin/env bash

set -e

# This shell script will download Cloudify resources from input locations, and prepare the VM to bootstrap
# a Cloudify environment.

env >> /tmp/bootstrap_script_env.txt
which python >> /tmp/bootstrap_script_env.txt
which wagon >> /tmp/bootstrap_script_env.txt
which cfy >> /tmp/bootstrap_script_env.txt


TEMP_DIR=$(ctx node properties bootstrap_working_directory)
mkdir -p ${TEMP_DIR}

###############################
# STEP 1: Download the manager resources package
# TODO: Not necessary since we're not using this offline any more?
MANAGER_RESOURCES_URL=$(ctx node properties mgr_resources_url)
ctx logger info "Downloading manager resources from ${MANAGER_RESOURCES_URL}"
curl -L -o ${TEMP_DIR}/cloudify-manager-resources.tar.gz ${MANAGER_RESOURCES_URL}

###############################
# STEP 2: Prepare the CLI machine

# Create some working directories
ROOT_SUBDIR=$(ctx node properties bootstrap_root_subdir)
ROOT_DIR=${TEMP_DIR}/${ROOT_SUBDIR}
mkdir -p ${ROOT_DIR}

MANAGER_SUBDIR=$(ctx node properties manager_subdir)
WORKING_DIR=${ROOT_DIR}/${MANAGER_SUBDIR}
mkdir -p ${WORKING_DIR}

OFFLINE_SUBDIR=$(ctx node properties offline_subdir)
OFFLINE_RESOURCES_DIR=${ROOT_DIR}/${OFFLINE_SUBDIR}
mkdir -p ${OFFLINE_RESOURCES_DIR}

# Grab the Manager Blueprints package and unpack in a MANAGER_BLUEPRINTS_DIR
MANAGER_BLUEPRINTS_URL=$(ctx node properties mgr_blueprints_url)
curl -L -o ${TEMP_DIR}/cloudify-manager-blueprints.tar.gz ${MANAGER_BLUEPRINTS_URL}

MANAGER_BLUEPRINTS_SUBDIR=$(ctx node properties manager_blueprints_subdir)
MANAGER_BLUEPRINTS_DIR=${ROOT_DIR}/${MANAGER_BLUEPRINTS_SUBDIR}
mkdir -p ${MANAGER_BLUEPRINTS_DIR}
cd ${MANAGER_BLUEPRINTS_DIR}
tar xvfz ${TEMP_DIR}/cloudify-manager-blueprints.tar.gz --strip-components=1

################################
## STEP 3: (Prepare Python virtual env) is skipped...assuming a dedicated VM
# for a Cloudify manager, and a separate node in the blueprint was responsible for
# installing cloudify, wagon, and all the other prerequisites for this.

###############################
# STEP 4: Download YAML files and DSL resources
# We need base Cloudify plugin files and AT&T-specific resources.
# Input is assumed to be a string containing inputs we can use for Cloudify YAMLs,
# repeating the same structure for AT&T-specific ones.
cd ${OFFLINE_RESOURCES_DIR}
DSL_SUBDIR=$(ctx node properties dsl_subdir)
mkdir -p ${DSL_SUBDIR} ; cd ${DSL_SUBDIR}

CLOUDIFY_YAML_BASE_URL=$(ctx node properties cfy_builtin_yaml_url)
CLOUDIFY_BUILTIN_YAML_LIST=$(ctx node properties cfy_builtin_yaml_list)
ctx logger info "Built-in YAML list properties imported as ${CLOUDIFY_BUILTIN_YAML_LIST}"
CLOUDIFY_DSL_SUBDIR=$(ctx node properties cfy_dsl_subdir)
# "spec" is something specific for Cloudify, needed in some places but not in others.
mkdir -p ${CLOUDIFY_DSL_SUBDIR}/spec ; cd ${CLOUDIFY_DSL_SUBDIR}/spec
declare -a yamls=(${CLOUDIFY_BUILTIN_YAML_LIST})
for y in "${yamls[@]}"; do curl -L --create-dirs -o ${y} ${CLOUDIFY_YAML_BASE_URL}/${y}; done | tee yaml-install.log

# TODO: insert other offline resources here.

###############################
# STEP 5: Download and install Wagon files
cd ${OFFLINE_RESOURCES_DIR}
mkdir -p plugins ; cd plugins
CLOUDIFY_WAGON_BASE_URL=$(ctx node properties cfy_wagon_url)
CLOUDIFY_WAGON_LIST=$(ctx node properties cfy_wagon_list)
declare -a wagon_list=(${CLOUDIFY_WAGON_LIST})
for y in "${wagon_list[@]}"; do curl -L -O ${CLOUDIFY_WAGON_BASE_URL}/${y}; done
# Assume all files in this dir are wagons to be installed
find . -type f -exec sudo wagon install {} \; | tee wagon-install.log

###############################
# STEP 6 (prepare manager inputs file). Use heredoc to echo env variables directly to yaml file.
# Download resource from blueprint directory and use jinja renderer to substitute in values
# as needed.

# One of the inputs is an ssh user, since Cloudify bootstrap connects to itself.
# We generate a new SSH key for this user on this machine and append the public key to the
# authorized keys file that we assume exists on this box.
cd ${WORKING_DIR}
BOOTSTRAP_SSH_KEY_FILENAME="cfy_bootstrap_key.pem"
ssh-keygen -t rsa -C "centos@cm" -f "${BOOTSTRAP_SSH_KEY_FILENAME}" -q -N ""
chmod 600 ${BOOTSTRAP_SSH_KEY_FILENAME}
cat ${BOOTSTRAP_SSH_KEY_FILENAME}.pub >> ${HOME}/.ssh/authorized_keys

SIMPLE_MGR_INPUTS_FILE=simple-manager-blueprint-inputs.yaml
ctx download-resource-and-render resources/simple-manager-blueprint-inputs-template.yaml ${WORKING_DIR}/${SIMPLE_MGR_INPUTS_FILE}
# IPs are inputs rather than attributes since they are run-time variables, so we can't use jinja
# templating to make them work. Use heredoc to append appropriate entries to the manager inputs file.
cat << EOF >> ${WORKING_DIR}/${SIMPLE_MGR_INPUTS_FILE}

public_ip: ${public_ip}
private_ip: ${public_ip}
ssh_user: ${LOGNAME}
ssh_key_filename: '${WORKING_DIR}/${BOOTSTRAP_SSH_KEY_FILENAME}'
EOF

###############################
# STEP 7: Initialize bootstrap directory
# This creates ${WORKING_DIR}/.cloudify/config.yaml, which we will modify in the configure step
# for an offline bootstrap.
cd ${WORKING_DIR}
cfy init -r

# Amend import resolver rules:
cat << EOF >> ${WORKING_DIR}/.cloudify/config.yaml
import_resolver:
  parameters:
    rules:
      - "http://www.getcloudify.org": "file://${OFFLINE_RESOURCES_DIR}/${DSL_SUBDIR}/${CLOUDIFY_DSL_SUBDIR}"
EOF

###############################
# STEP 8: Kick off bootstrap
# May also want the --keep-up-on-failure directive on the bootstrap.
cfy bootstrap -p ${MANAGER_BLUEPRINTS_DIR}/simple-manager-blueprint.yaml -i ${WORKING_DIR}/simple-manager-blueprint-inputs.yaml --debug | tee ${WORKING_DIR}/bootstrap.log
