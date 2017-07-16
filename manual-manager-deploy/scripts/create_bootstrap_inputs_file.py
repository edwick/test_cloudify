#!/usr/bin/python
# Use system python rather than the env python provided by Cloudify, since it does not seem to have
# the yaml library in it

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

from cloudify.state import ctx_parameters as inputs

# Utility function to format a string nicely for DSL resources.
def format_dsl_string(resource, source_prefix, dest_prefix):
    source_path = os.path.join(source_prefix, resource)
    dest_path = os.path.join(dest_prefix, resource)
    formatted_dsl_string = "'source_path': '{0}', 'destination_path': '{1}'".format(source_path, dest_path)
    return "{" + formatted_dsl_string + "}"

TEMP_DIR = ctx.node.properties['bootstrap_working_directory']
bootstrap_subdir = 'cloudify-bootstrap'
bootstrap_dir = os.path.join(TEMP_DIR, bootstrap_subdir)
mgr_blueprints_subdir = 'manager-blueprints'

cloudify_source_input_filename = os.path.join(bootstrap_dir,
                                              mgr_blueprints_subdir,
                                              'simple-manager-blueprint-inputs.yaml')

with open(cloudify_source_input_filename) as fp:
    bootstrap_config = yaml.load(fp)

# Construct bootstrap inputs with values specified in node properties and with other values
# where we expect them to be.
# In this case, we set both public and private IP to the same address.
public_ip_address = inputs['public_ip']
ctx.logger.info('Public IP address received by node as {0}'.format(public_ip_address))
bootstrap_config['public_ip'] = public_ip_address
bootstrap_config['private_ip'] = public_ip_address

mgr_resources_pkg_filename = os.path.join(bootstrap_dir, 'cloudify-manager-resources.tar.gz')
mgr_resources_as_url = urlparse.urljoin('file:', urllib.pathname2url(mgr_resources_pkg_filename))
bootstrap_config['manager_resources_package'] = mgr_resources_as_url

bootstrap_config['admin_username'] = ctx.node.properties['admin_username']
bootstrap_config['admin_password'] = ctx.node.properties['admin_password']

working_subdir = 'manager'
full_working_dir_path = os.path.join(bootstrap_dir,
                                     working_subdir)
manager_inputs_filename = os.path.join(full_working_dir_path,
                                       'manager-inputs.yaml')

# LISTS OF EXTRA INPUTS THAT HAVE TO GO INTO THE YAML INPUTS FILE
offline_rsrc_subdir = 'offline-resources'
offline_dir_path = os.path.join(bootstrap_dir,
                                offline_rsrc_subdir)
dsl_subdir = 'dsl'
dsl_dir_path = os.path.join(offline_dir_path,
                            dsl_subdir)
dsl_resource_list = ctx.node.properties['cfy_builtin_yaml_list'].split(' ')
dest_root = '/spec'
dsl_resources = [ format_dsl_string(next_resource, dsl_dir_path, dest_root)
                  for next_resource in dsl_resource_list ]
# Plugins are just a list of strings pointing at URLs for resources.
# None at the moment, but we might use this later for more interesting things.
PLUGIN_RESOURCES = [

]

# Dump out inputs file. We write manually because the yaml.dump function does some odd things
# with types in here.
with open(manager_inputs_filename, 'w') as fp:
    for next_key, next_value in bootstrap_config.iteritems():
        fp.write('{0}: {1}\n'.format(next_key, next_value))
    # Dump out dsl resources
    fp.write('dsl_resources:\n')
    for next_resource in dsl_resources:
        fp.write('  - {0}\n'.format(next_resource))
    fp.write('\n')
    if PLUGIN_RESOURCES:
        fp.write('plugin_resources:\n')
        for next_plugin in PLUGIN_RESOURCES:
            fp.write("  - '{0}'\n".format(next_plugin))
    fp.write('\n')


# Modify WORKING_DIR/.cloudify/config.yaml directory to add import resolver rules
IMPORT_RESOLVER_RULE = """
import_resolver:
  parameters:
    rules:
      - "http://www.getcloudify.org/spec": "file://{0}"
""".format(dsl_dir_path)
config_yaml_path = os.path.join(full_working_dir_path, '.cloudify', 'config.yaml')
with open(config_yaml_path,'a') as fp:
    fp.write(IMPORT_RESOLVER_RULE)

