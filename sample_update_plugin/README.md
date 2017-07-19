# sample_update_plugin

This is a very simple operations plugin that will add text to a file on a target VM. It is intended as a small, working
example of how to implement a Cloudify operations plugin with the intention of using it in custom workflows.

## operations

cloudify.sample_update.file_operations.create_new_config: Create new file in the VM and append text.
File name is a node property, text is an input.

cloudify.sample_update.file_operations.update_existing_config: This operation will update an existing file rather
 than overwriting it.