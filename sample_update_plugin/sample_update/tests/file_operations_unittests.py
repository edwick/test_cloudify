"""
Unit tests for file operations plugin Python module
"""

import unittest
import os

from cloudify.mocks import MockCloudifyContext
from cloudify.state import current_ctx

from sample_update_plugin.sample_update import file_operations

class FileOperationsUnitTests(unittest.TestCase):


    def setUp(self):
        self.test_file_path = os.tmpnam()
        # Make sure we don't have an existing file there; the append test will create one
        # on its own.
        if os.path.isfile(self.test_file_path):
            os.remove(self.test_file_path)
        node_properties = {file_operations.FILE_PATH_PROPERTY_NAME: self.test_file_path}
        mock_ctx = MockCloudifyContext(node_id='test_node_id',
                                            node_name='test_node_name',
                                            properties=node_properties)
        current_ctx.set(mock_ctx)

    def tearDown(self):
        # Remove the test file we create.
        if os.path.isfile(self.test_file_path):
            os.remove(self.test_file_path)
        current_ctx.clear()

    def test_create_new_config(self):
        self.assertFalse(os.path.isfile(self.test_file_path))
        expected_contents = 'This is a test string'
        file_operations.create_new_config(input_string=expected_contents)
        self.assertTrue(os.path.isfile(self.test_file_path))
        with open(self.test_file_path) as fp:
            file_contents = fp.read()
            # Note that our call is appending a newline to the incoming contents.
            self.assertEqual(file_contents, expected_contents + '\n')

    def test_update_config(self):
        initial_input = 'This is the first line of the file'
        with open(self.test_file_path,'w') as fp:
            fp.write(initial_input+'\n')
        new_input = 'This is the second line of the file'
        file_operations.update_existing_config(input_string=new_input)
        with open(self.test_file_path) as fp:
            file_contents = fp.read()
            split_contents = file_contents.split('\n')
            self.assertEqual(len(split_contents), 3)
            self.assertEqual(split_contents[0], initial_input)
            self.assertEqual(split_contents[1], new_input)

if __name__ == '__main__':
    unittest.main()
