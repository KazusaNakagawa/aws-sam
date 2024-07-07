import boto3
import json
import sys
from datetime import datetime


def get_lambda_arn(lambda_client, function_name):
    response = lambda_client.get_function(FunctionName=function_name)
    return response["Configuration"]["FunctionArn"]


def add_lambda_permission(lambda_client, function_name, bucket_name, statement_id, account_id):
    lambda_client.add_permission(
        FunctionName=function_name,
        StatementId=statement_id,
        Action="lambda:InvokeFunction",
        Principal="s3.amazonaws.com",
        SourceArn=f"arn:aws:s3:::{bucket_name}",
        SourceAccount=account_id,
    )


def update_s3_notification(s3_client, bucket_name, new_config):
    current_config = s3_client.get_bucket_notification_configuration(Bucket=bucket_name)

    # Remove ResponseMetadata from current configuration
    current_config.pop("ResponseMetadata", None)

    if "LambdaFunctionConfigurations" not in current_config:
        current_config["LambdaFunctionConfigurations"] = []

    current_config["LambdaFunctionConfigurations"].append(new_config)

    s3_client.put_bucket_notification_configuration(Bucket=bucket_name, NotificationConfiguration=current_config)


def main(env, input_bucket_name, lambda_function_name, s3_prefix, s3_suffix, profile):
    session = boto3.Session(profile_name=profile)
    lambda_client = session.client("lambda")
    s3_client = session.client("s3")
    sts_client = session.client("sts")

    account_id = sts_client.get_caller_identity()["Account"]

    lambda_arn = get_lambda_arn(lambda_client, lambda_function_name)
    print(f"Lambda Function ARN: {lambda_arn}")

    statement_id = f"{lambda_function_name}-{int(datetime.now().timestamp())}"
    add_lambda_permission(lambda_client, lambda_function_name, input_bucket_name, statement_id, account_id)
    print("Permission added successfully")

    new_notification_config = {
        "LambdaFunctionArn": lambda_arn,
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {"Key": {"FilterRules": [{"Name": "prefix", "Value": s3_prefix}]}},
    }

    if s3_suffix:
        new_notification_config["Filter"]["Key"]["FilterRules"].append({"Name": "suffix", "Value": s3_suffix})

    update_s3_notification(s3_client, input_bucket_name, new_notification_config)
    print("S3 Notification Configuration updated successfully")


if __name__ == "__main__":
    if len(sys.argv) != 7:
        print(
            "Usage: python setup_s3_trigger.py <env> <input_bucket_name> <lambda_function_name> <s3_prefix> <s3_suffix> <profile>"
        )
        sys.exit(1)

    env, input_bucket_name, lambda_function_name, s3_prefix, s3_suffix, profile = sys.argv[1:]
    main(env, input_bucket_name, lambda_function_name, s3_prefix, s3_suffix, profile)
