#!/bin/bash

# Usage: ./setup_s3_trigger.sh <env> <input_bucket_name> <lambda_function_name> <s3_prefix> <s3_suffix> <profile>
# Example: ./setup_s3_trigger.sh dev my-input-bucket my-lambda-function my-prefix my-suffix default

# Check if environment argument is provided
if [ -z "$1" ]; then
  echo "Environment argument is required."
  echo "Usage: $0 <env> <input_bucket_name> <lambda_function_name> <s3_prefix> <s3_suffix> <profile>" 
  exit 1
fi

ENV=$1
INPUT_BUCKET_NAME=$2
LAMBDA_FUNCTION_NAME=$3
S3_PREFIX=$4
S3_SUFFIX=$5
PROFILE=$6

# Get the Lambda function ARN
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name ${LAMBDA_FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text --profile ${PROFILE})

if [ -z "$LAMBDA_FUNCTION_ARN" ]; then
  echo "Lambda function ${LAMBDA_FUNCTION_NAME} does not exist."
  exit 1
fi

echo "Lambda Function ARN: ${LAMBDA_FUNCTION_ARN}"

# Generate a unique statement ID using timestamp and lambda function name
STATEMENT_ID="${LAMBDA_FUNCTION_NAME}-$(date +%s)"

# Add permission for S3 to invoke the Lambda function
aws lambda add-permission --function-name ${LAMBDA_FUNCTION_NAME} \
  --principal s3.amazonaws.com \
  --statement-id ${STATEMENT_ID} \
  --action "lambda:InvokeFunction" \
  --source-arn arn:aws:s3:::${INPUT_BUCKET_NAME} \
  --source-account $(aws sts get-caller-identity --query Account --output text --profile ${PROFILE})

if [ $? -ne 0 ]; then
  echo "Failed to add permission to Lambda function for S3 invocation."
  exit 1
fi

# Create new S3 event notification configuration
if [ -n "$S3_SUFFIX" ]; then
  NEW_NOTIFICATION_CONFIGURATION=$(cat <<EOF
{
  "LambdaFunctionArn": "${LAMBDA_FUNCTION_ARN}",
  "Events": ["s3:ObjectCreated:*"],
  "Filter": {
    "Key": {
      "FilterRules": [
        {"Name": "prefix", "Value": "${S3_PREFIX}"},
        {"Name": "suffix", "Value": "${S3_SUFFIX}"}
      ]
    }
  }
}
EOF
  )
else
  NEW_NOTIFICATION_CONFIGURATION=$(cat <<EOF
{
  "LambdaFunctionArn": "${LAMBDA_FUNCTION_ARN}",
  "Events": ["s3:ObjectCreated:*"],
  "Filter": {
    "Key": {
      "FilterRules": [
        {"Name": "prefix", "Value": "${S3_PREFIX}"}
      ]
    }
  }
}
EOF
  )
fi

echo "New Notification Configuration: ${NEW_NOTIFICATION_CONFIGURATION}"

# 現在のS3バケット通知設定を取得
# aws s3api get-bucket-notification-configuration --bucket s3-copy-source-bucket-dev --profile Admin
CURRENT_NOTIFICATION_CONFIGURATION=$(aws s3api get-bucket-notification-configuration --bucket ${INPUT_BUCKET_NAME} --profile ${PROFILE})

# 通知設定が存在しない場合は、空の通知設定を作成
if [ -z "$CURRENT_NOTIFICATION_CONFIGURATION" ]; then
  CURRENT_NOTIFICATION_CONFIGURATION='{}'
fi

# Pythonを使用して新しい通知設定をマージ
UPDATED_NOTIFICATION_CONFIGURATION=$(python3 - <<EOF
import json

current_config = json.loads('''${CURRENT_NOTIFICATION_CONFIGURATION}''')
new_config = json.loads('''${NEW_NOTIFICATION_CONFIGURATION}''')

if 'LambdaFunctionConfigurations' not in current_config:
    current_config['LambdaFunctionConfigurations'] = []

current_config['LambdaFunctionConfigurations'].append(new_config)

print(json.dumps(current_config))
EOF
)

echo "Updated Notification Configuration: ${UPDATED_NOTIFICATION_CONFIGURATION}"

# Apply the updated S3 bucket notification configuration
aws s3api put-bucket-notification-configuration --bucket ${INPUT_BUCKET_NAME} --notification-configuration "${UPDATED_NOTIFICATION_CONFIGURATION}" --profile ${PROFILE}

if [ $? -ne 0 ]; then
  echo "Failed to configure S3 bucket notifications."
  exit 1
fi

echo "Successfully configured S3 trigger for Lambda function ${LAMBDA_FUNCTION_NAME}."
