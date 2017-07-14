#
# Python module that reads in the default bootstrap inputs file and substitutes in proper values
# for the required inputs.
# Current implementation adds in supplemental resources as large objects statically defined here.
# This is not an ideal way to manage these, but it is a shortcut for now until we can come up with
# Something Better.
#

import yaml
import os
import urlparse, urllib
from cloudify import ctx

# STATICALLY DEFINED LISTS OF EXTRA INPUTS THAT HAVE TO GO INTO THE YAML INPUTS FILE
# We know we have a list of incoming types that need to be remapped.
# Unfortunately, the Cloudify Manager inputs file mixes metaphors and crafts a list of Python-style
# dictionaries in the inputs YAML file rather than using full YAML syntax for "dsl_resources".
DSL_RESOURCES = [
    "{'source_path': '/home/centos/cloudify/offline/dsl/openstack-plugin/1.4/plugin.yaml', 'destination_path': '/spec/openstack-plugin/1.4/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/aws-plugin/1.4.1/plugin.yaml', 'destination_path': '/spec/aws-plugin/1.4.1/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/tosca-vcloud-plugin/1.3.1/plugin.yaml', 'destination_path': '/spec/tosca-vcloud-plugin/1.3.1/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/vsphere-plugin/2.0/plugin.yaml', 'destination_path': '/spec/vsphere-plugin/2.0/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/fabric-plugin/1.4.1/plugin.yaml', 'destination_path': '/spec/fabric-plugin/1.4.1/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/diamond-plugin/1.3.3/plugin.yaml', 'destination_path': '/spec/diamond-plugin/1.3.3/plugin.yaml'}",
    "{'source_path': '/home/centos/cloudify/offline/dsl/cloudify/3.4.1/types.yaml', 'destination_path': '/spec/cloudify/3.4.1/types.yaml'}"]
# Plugins are just a list of names - which we don't have at exactly this moment
PLUGIN_RESOURCES = [

]


TEMP_DIR = ctx.node.properties['bootstrap_working_directory']
bootstrap_subdir = 'cloudify-bootstrap'
mgr_blueprints_subdir = 'manager-blueprints'

cloudify_source_input_filename = os.path.join(TEMP_DIR,
                                              bootstrap_subdir,
                                              mgr_blueprints_subdir,
                                              'simple-manager-blueprint-inputs.yaml')

with open(cloudify_source_input_filename) as fp:
    bootstrap_config = yaml.load(fp)

# Construct bootstrap inputs with values specified in node properties and with other values
# where we expect them to be.
# In this case, we set both public and private IP to the same address.
bootstrap_config['public_ip'] = ctx.node.properties['public_ip']
bootstrap_config['private_ip'] = ctx.node.properties['public_ip']

mgr_resources_pkg_filename = os.path.join(TEMP_DIR, 'cloudify-manager-resources.tar.gz')
mgr_resources_as_url = urlparse.urljoin('file:', urllib.pathname2url(mgr_resources_pkg_filename))
bootstrap_config['manager_resources_package'] = mgr_resources_as_url

bootstrap_config['dsl_resources'] = DSL_RESOURCES
#bootstrap_config['plugin_resources'] = PLUGIN_RESOURCES

working_subdir = 'manager'
manager_inputs_filename = os.path.join(TEMP_DIR,
                                       bootstrap_subdir,
                                       working_subdir,
                                       'manager-inputs.yaml')

with open(manager_inputs_filename, 'w') as fp:
    # default_flow_style dumps YAML file in "key: value" format rather than as a Python dict
    yaml.dump(bootstrap_config, fp, default_flow_style=False)
