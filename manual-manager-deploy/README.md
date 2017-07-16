This blueprint will deploy an Openstack VM on a specified tenant
and then bootstrap a Cloudify Manager (v3.4) on it.

This blueprint follows Cloudify's recommendation for offline installs, assuming that all necessary resources for an 
install are available locally.
 
Implementation will be handled mostly through shell scripts and/or Python calls to download all required
resources, create the necessary configuration files, and execute the deployment.

PREREQUISITES:
1. An OpenStack image that has all Cloudify Manager pre-requisites installed on it (gcc, python-devel, etc).
2. An SSH key that is accessible on the CURRENTLY RUNNING Cloudify Manager machine.

INPUTS:
(TBD)

IMPLEMENTATION:
Cloudify Manager node will be contained in the VM, and execute the following steps in the install lifecycle:

1. create: Download components and setup environment (shell)
2. configure: Prepare inputs file (python so we can use the nice YAML library rather than shell tools)
3. start: Execute bootstrap operation (shell)