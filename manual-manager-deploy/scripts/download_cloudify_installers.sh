#!/usr/bin/env bash

# This shell script will download Cloudify resources from input locations, and prepare the VM to bootstrap
# a Cloudify environment.

TEMP_DIR=$(ctx node properties bootstrap_working_directory)
mkdir -p ${TEMP_DIR}

###############################
# STEP 1: Download the manager resources package
MANAGER_RESOURCES_URL=$(ctx node properties mgr_resources_url)
ctx logger info "Downloading manager resources from ${MANAGER_RESOURCES_URL}"
curl -L -o ${TEMP_DIR}/cloudify-manager-resources.tar.gz ${MANAGER_RESOURCES_URL}

###############################
# STEP 2: Prepare the CLI machine

# Create some working directories
ROOT_DIR=${TEMP_DIR}/cloudify-bootstrap
mkdir -p ${ROOT_DIR}
WORKING_DIR=${ROOT_DIR}/manager
mkdir -p ${WORKING_DIR}
OFFLINE_RESOURCES_DIR=${ROOT_DIR}/offline-resources
mkdir -p ${OFFLINE_RESOURCES_DIR}

# Grab the Manager Blueprints package and unpack in a MANAGER_BLUEPRINTS_DIR
MANAGER_BLUEPRINTS_URL=$(ctx node properties mgr_blueprints_url)
curl -L -o ${TEMP_DIR}/cloudify-manager-blueprints.tar.gz ${MANAGER_BLUEPRINTS_URL}

MANAGER_BLUEPRINTS_DIR=${ROOT_DIR}/manager-blueprints
mkdir -p ${MANAGER_BLUEPRINTS_DIR}
cd ${MANAGER_BLUEPRINTS_DIR}
tar xvfz ${TEMP_DIR}/cloudify-manager-blueprints.tar.gz --strip-components=1

###############################
# STEP 3: Prepare Python virtual environment
# NOTE: We assume the tools we need are already installed for the VM that we are running on.
# May well remove this step and force the VM image to have cloudify or wagon already installed also.
# TODO: CLI Version to be changed to input
CLI_VERSION=$(ctx node properties cli_version)
virtualenv ${ROOT_DIR}/cfy_env
source ${ROOT_DIR}/cfy_env/bin/activate
pip install cloudify==${CLI_VERSION}
pip install wagon

###############################
# STEP 4: Download YAML files and DSL resources
# We need base Cloudify plugin files and AT&T-specific resources.
# Input is assumed to be a string containing inputs we can use for Cloudify YAMLs,
# repeating the same structure for AT&T-specific ones.
CLOUDIFY_YAML_BASE_URL=$(ctx node properties cfy_builtin_yaml_url)
CLOUDIFY_BUILTIN_YAML_LIST=$(ctx node properties cfy_builtin_yaml_list)
ctx logger info "Built-in YAML list properties imported as ${CLOUDIFY_BUILTIN_YAML_LIST}"
cd ${OFFLINE_RESOURCES_DIR}
mkdir dsl ; cd dsl
declare -a yamls=(${CLOUDIFY_BUILTIN_YAML_LIST})
for y in "${yamls[@]}"; do curl -L --create-dirs -o ${y} ${CLOUDIFY_YAML_BASE_URL}/${y}; done

###############################
# STEP 5: Download and install Wagon files
cd ${OFFLINE_RESOURCES_DIR}
mkdir plugins ; cd plugins
# TODO: Set wagon base URL and wagon list from ctx
CLOUDIFY_WAGON_BASE_URL=$(ctx node properties cfy_wagon_url)
CLOUDIFY_WAGON_LIST=$(ctx node properties cfy_wagon_list)
declare -a wagon_list=(${CLOUDIFY_WAGON_LIST})
for y in "${wagon_list[@]}"; do curl -L -O ${CLOUDIFY_WAGON_BASE_URL}/${y}; done
# Assume all files in this dir are wagons to be installed
find . -type f -exec wagon install -s {} \;
