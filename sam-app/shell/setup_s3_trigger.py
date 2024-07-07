import boto3
import json
import sys

COMMON_BUCKET_NAME = "s3-copy-input-bucket-common"


def get_lambda_arn(lambda_client, function_name):
    response = lambda_client.get_function(FunctionName=function_name)
    return response["Configuration"]["FunctionArn"]


def remove_existing_permission(lambda_client, function_name, statement_id):
    try:
        lambda_client.remove_permission(FunctionName=function_name, StatementId=statement_id)
        print(f"Removed existing permission with StatementId {statement_id}")
    except lambda_client.exceptions.ResourceNotFoundException:
        print(f"No existing permission with StatementId {statement_id} found")


def add_lambda_permission(lambda_client, function_name, bucket_name, statement_id, account_id):
    lambda_client.add_permission(
        FunctionName=function_name,
        StatementId=statement_id,
        Action="lambda:InvokeFunction",
        Principal="s3.amazonaws.com",
        SourceArn=f"arn:aws:s3:::{bucket_name}",
        SourceAccount=account_id,
    )
    print(f"Added permission with StatementId {statement_id}")


def update_s3_notification(s3_client, bucket_name, new_config):
    current_config = s3_client.get_bucket_notification_configuration(Bucket=bucket_name)

    # Remove ResponseMetadata from current configuration
    current_config.pop("ResponseMetadata", None)

    if "LambdaFunctionConfigurations" not in current_config:
        current_config["LambdaFunctionConfigurations"] = []

    current_config["LambdaFunctionConfigurations"].append(new_config)

    s3_client.put_bucket_notification_configuration(Bucket=bucket_name, NotificationConfiguration=current_config)


def trigger_s3_event(s3_client, bucket_name, lambda_arn, s3_prefix, s3_suffix):
    new_notification_config = {
        "LambdaFunctionArn": lambda_arn,
        "Events": ["s3:ObjectCreated:*"],
        "Filter": {"Key": {"FilterRules": [{"Name": "prefix", "Value": s3_prefix}]}},
    }

    if s3_suffix:
        new_notification_config["Filter"]["Key"]["FilterRules"].append({"Name": "suffix", "Value": s3_suffix})

    print(f"New Notification Configuration: {json.dumps(new_notification_config, indent=2)}")

    current_notification_config = s3_client.get_bucket_notification_configuration(Bucket=bucket_name)
    # Remove ResponseMetadata from current configuration
    current_notification_config.pop("ResponseMetadata", None)

    if "LambdaFunctionConfigurations" not in current_notification_config:
        current_notification_config["LambdaFunctionConfigurations"] = []

    current_notification_config["LambdaFunctionConfigurations"].append(new_notification_config)

    return current_notification_config


def create_unique_statement_id(lambda_function_name, lambda_client, bucket_name, account_id):
    """既存のステートメントIDを確認し、存在する場合はそれを削除してから同盟のステートメントIDを作成する
    そうすることで、同じステートメントIDで複数のLambda関数に対して権限を付与することを防ぐ
    """
    statement_id = f"{lambda_function_name}-s3-invoke-{bucket_name}"
    # Remove existing permission if exists
    remove_existing_permission(lambda_client, lambda_function_name, statement_id)
    # Add new permissionzxxz
    add_lambda_permission(lambda_client, lambda_function_name, bucket_name, statement_id, account_id)


def create_s3_trigger(env, s3_client, lambda_client, account_id, lambda_events, input_bucket_name):

    # Clear existing notification configuration to avoid conflicts
    s3_client.put_bucket_notification_configuration(Bucket=f"{input_bucket_name}-{env}", NotificationConfiguration={})
    s3_client.put_bucket_notification_configuration(Bucket=COMMON_BUCKET_NAME, NotificationConfiguration={})

    for lambda_function_name, bucket_name, s3_prefix, s3_suffix in lambda_events:
        print(f"Lambda Function Name: {lambda_function_name}")
        print(f"Input Bucket Name: {bucket_name}")
        print(f"S3 Prefix: {s3_prefix}")
        print(f"S3 Suffix: {s3_suffix}")

        lambda_arn = get_lambda_arn(lambda_client, lambda_function_name)
        print(f"Lambda Function ARN: {lambda_arn}")

        create_unique_statement_id(lambda_function_name, lambda_client, bucket_name, account_id)

        current_notification_config = trigger_s3_event(s3_client, bucket_name, lambda_arn, s3_prefix, s3_suffix)

        updated_notification_config = json.dumps(current_notification_config)
        print(f"Updated Notification Configuration: {updated_notification_config}")

        s3_client.put_bucket_notification_configuration(
            Bucket=bucket_name, NotificationConfiguration=current_notification_config
        )
        print(f"Successfully configured S3 trigger for Lambda function {lambda_function_name}.")


def main(env, input_bucket_name, profile):
    session = boto3.Session(profile_name=profile)
    lambda_client = session.client("lambda")
    s3_client = session.client("s3")
    sts_client = session.client("sts")

    account_id = sts_client.get_caller_identity()["Account"]

    # TODO: ここは設定ファイルから読み込むようにすると処理を切り分けやすくなる
    lambda_events = [
        (f"s3-copy-lambda-{env}", f"{input_bucket_name}-{env}", "input/", ".json"),
        (f"s3-copy-lambda2-{env}", f"{input_bucket_name}-{env}", "prefix/", ".tsv.gz"),
        (f"s3-copy-lambda-{env}", COMMON_BUCKET_NAME, "input/", ".tsv.gz"),
        (f"s3-copy-lambda2-{env}", COMMON_BUCKET_NAME, "input2/", "*.tsv.gz"),
    ]

    create_s3_trigger(env, s3_client, lambda_client, account_id, lambda_events, input_bucket_name)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python setup_s3_trigger.py <env> <input_bucket_name> <profile>")
        sys.exit(1)

    env, input_bucket_name, profile = sys.argv[1:]
    main(env, input_bucket_name, profile)
