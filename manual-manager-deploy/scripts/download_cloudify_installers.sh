#!/usr/bin/env bash

set -e

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

################################
## STEP 3: Prepare Python virtual environment
## NOTE: We assume the tools we need are already installed for the VM that we are running on.
#which virtualenv &>> /tmp/pythontools_output.txt
#echo "*******" &>> /tmp/pythontools_output.txt
#virtualenv --version &>> /tmp/pythontools_output.txt
#echo "*******" &>> /tmp/pythontools_output.txt
#/usr/bin/virtualenv --version &>> /tmp/pythontools_output.txt
#echo "*******" &>> /tmp/pythontools_output.txt
#/usr/bin/virtualenv ${ROOT_DIR}/cfy_env &>> /tmp/pythontools_output.txt
#echo "*******" &>> /tmp/pythontools_output.txt
#find ${ROOT_DIR}/cfy_env &>> /tmp/pythontools_output.txt
#echo "*******" &>> /tmp/pythontools_output.txt
#source ${ROOT_DIR}/cfy_env/bin/activate &>> /tmp/pythontools_output.txt
## Install cloudify while we're here
#CLI_VERSION=$(ctx node properties cloudify_cli_version)
#pip install cloudify==${CLI_VERSION}
#pip install wagon

###############################
# STEP 4: Download YAML files and DSL resources
# We need base Cloudify plugin files and AT&T-specific resources.
# Input is assumed to be a string containing inputs we can use for Cloudify YAMLs,
# repeating the same structure for AT&T-specific ones.
CLOUDIFY_YAML_BASE_URL=$(ctx node properties cfy_builtin_yaml_url)
CLOUDIFY_BUILTIN_YAML_LIST=$(ctx node properties cfy_builtin_yaml_list)
ctx logger info "Built-in YAML list properties imported as ${CLOUDIFY_BUILTIN_YAML_LIST}"
cd ${OFFLINE_RESOURCES_DIR}
mkdir -p dsl ; cd dsl
declare -a yamls=(${CLOUDIFY_BUILTIN_YAML_LIST})
for y in "${yamls[@]}"; do curl -L --create-dirs -o ${y} ${CLOUDIFY_YAML_BASE_URL}/${y}; done

###############################
# STEP 5: Download and install Wagon files
cd ${OFFLINE_RESOURCES_DIR}
mkdir -p plugins ; cd plugins
# TODO: Set wagon base URL and wagon list from ctx
CLOUDIFY_WAGON_BASE_URL=$(ctx node properties cfy_wagon_url)
CLOUDIFY_WAGON_LIST=$(ctx node properties cfy_wagon_list)
declare -a wagon_list=(${CLOUDIFY_WAGON_LIST})
for y in "${wagon_list[@]}"; do curl -L -O ${CLOUDIFY_WAGON_BASE_URL}/${y}; done
# Assume all files in this dir are wagons to be installed
#find . -type f -exec wagon install -s {} \;

###############################
# STEP 6 (prepare manager inputs file). Use heredoc to echo env variables directly to yaml file.
# Recall that heredoc doesn't inherit the ctx variable
ADMIN_USERNAME=${ctx node properties admin_username}
ADMIN_PASSWORD=${ctx node properties admin_password}
echo "Admin username/password is ${ADMIN_USERNAME}/${ADMIN_PASSWORD}" >> /tmp/admin_info.txt
cat << EOF > ${WORKING_DIR}/manager-inputs.yaml
public_ip: ${public_ip}
private_ip: ${public_ip}
manager_resources_package: file://${TEMP_DIR}/cloudify-manager-resources.tar.gz
admin_username: ${ADMIN_USERNAME}
admin_password: ${ADMIN_PASSWORD}
dsl_resources:
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/cloudify/3.4.1/types.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/cloudify/3.4.1/types.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/fabric-plugin/1.4.1/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/fabric-plugin/1.4.1/plugin.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/openstack-plugin/1.4/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/openstack-plugin/1.4/plugin.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/aws-plugin/1.4.1/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/aws-plugin/1.4.1/plugin.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/tosca-vcloud-plugin/1.3.1/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/tosca-vcloud-plugin/1.3.1/plugin.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/vsphere-plugin/2.0/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/vsphere-plugin/2.0/plugin.yaml'"'"'}
  - {'"'"'source_path'"'"': '"'"'${OFFLINE_RESOURCES_DIR}/dsl/diamond-plugin/1.3.3/plugin.yaml'"'"', '"'"'destination_path'"'"': '"'"'/spec/diamond-plugin/1.3.3/plugin.yaml'"'"'}
EOF

###############################
# STEP 7: First part - Initialize bootstrap directory
# This creates ${WORKING_DIR}/.cloudify/config.yaml, which we will modify in the configure step
# for an offline bootstrap.
cd ${WORKING_DIR}
cfy init -r

# Amend import resolver rules:
cat << EOF >> ${WORKING_DIR}/.cloudify/config.yaml
import_resolver:
  parameters:
    rules:
      - "http://www.getcloudify.org/spec": "file://${OFFLINE_RESOURCES_DIR}/dsl"
EOF

