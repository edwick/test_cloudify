"""
 Plugin method implementations to create or update a file, with the file name specified as a node
 property and a line to be added to the file specified as a node input.
"""

# ctx is imported and used in operations
from cloudify import ctx

# put the operation decorator on any function that is a task
from cloudify.decorators import operation

FILE_PATH_PROPERTY_NAME = 'path_to_file_we_should_update'

@operation
def create_new_config(input_string, **kwargs):
    # filename comes from context property.
    input_filename = ctx.node.properties[FILE_PATH_PROPERTY_NAME]
    ctx.logger.info('Creating new file {0}, appending input string {1}'.format(input_filename, input_string))
    with open(input_filename, 'w') as fp:
        fp.write(input_string)
        fp.write('\n')

@operation
def update_existing_config(input_string, **kwargs):
    # Toy example: only difference is the file mode
    input_filename = ctx.node.properties[FILE_PATH_PROPERTY_NAME]
    ctx.logger.info('Appending to existing file {0}, appending input string {1}'.format(input_filename, input_string))
    with open(input_filename, 'a') as fp:
        fp.write(input_string)
        fp.write('\n')
