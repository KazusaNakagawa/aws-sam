import pytest
from datetime import datetime as dt

from handler import s3copy

s3copy.TARGET_CONFIG = "./handler/config/target.json"

class TestHandler:
    def test_s3copy(self, mocker, monkeypatch):
        monkeypatch.setenv("TARGET_BUCKET", "example-bucket")
        source_key = "input/test1.json"
        event = {
            "Records": [
                {
                    "s3": {
                        "bucket": {
                            "name": "s3-copy-*******"
                        },
                        "object": {
                            "key": source_key
                        }
                    }
                }
            ]
        }
        context = {}
        mock_s3_client = mocker.patch('handler.s3copy.s3')
        mock_s3_client.copy_object.return_value = {}

        # Act
        result = s3copy.handler(event, context)

        # Assert
        dt_now = dt.now().strftime("%Y/%m/%d")
        mock_s3_client.copy_object.assert_called_once_with(
            Bucket="example-bucket",
            CopySource={
                "Bucket": "s3-copy-*******",
                "Key": source_key
            },
            Key=f"test1_prefix/{dt_now}/{source_key}",
        )
        assert result == {'statusCode': 200, 'body': f'"Successfully copied {source_key}"'}
