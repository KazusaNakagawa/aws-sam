import json

import pytest

from handler import s3copy

class TestHandler:

      def test_handler(self):
         event = {
               'Records': [
                  {
                     's3': {
                           'bucket': {
                              'name': 'sourcebucket'
                           },
                           'object': {
                              'key': 'HappyFace.jpg'
                           }
                     }
                  }
               ]
         }
         assert s3copy(event, None) == 'Hello from Lambda!'
