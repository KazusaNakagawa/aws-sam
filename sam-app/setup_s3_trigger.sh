#!/bin/bash

# Usage: ./setup_s3_trigger.sh <env>
# Example: ./setup_s3_trigger.sh dev

# Check if environment argument is provided
if [ -z "$1" ]; then
  echo "Environment argument is required."
  echo "Usage: $0 <env> <s3_bucket_name> <s3_prefix> <s3_suffix>"
  exit 1
fi

# Assign environment argument to variable
ENV=$1
# S3_BUCKET_NAME=$2
S3_BUCKET_NAME="s3-copy-source-bucket-dev"
# S3_PREFIX=$3
S3_PREFIX="input/"
# S3_SUFFIX=$4
S3_SUFFIX=".json"

# Define Lambda function name
LAMBDA_FUNCTION_NAME="s3-copy-lambda-${ENV}"

# Get the Lambda function ARN
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name ${LAMBDA_FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text)

if [ -z "$LAMBDA_FUNCTION_ARN" ]; then
  echo "Lambda function ${LAMBDA_FUNCTION_NAME} does not exist."
  exit 1
fi

echo "Lambda Function ARN: ${LAMBDA_FUNCTION_ARN}"

# Add permission for S3 to invoke the Lambda function
aws lambda add-permission --function-name ${LAMBDA_FUNCTION_NAME} --principal s3.amazonaws.com --statement-id s3invoke --action "lambda:InvokeFunction" --source-arn arn:aws:s3:::${S3_BUCKET_NAME} --source-account $(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]; then
  echo "Failed to add permission to Lambda function for S3 invocation."
  exit 1
fi

# Create S3 event notification configuration
S3_NOTIFICATION_CONFIGURATION=$(cat <<EOF
{
  "LambdaFunctionConfigurations": [
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
  ]
}
EOF
)

echo "S3 Notification Configuration: ${S3_NOTIFICATION_CONFIGURATION}"

# Apply the S3 bucket notification configuration
aws s3api put-bucket-notification-configuration --bucket ${S3_BUCKET_NAME} --notification-configuration "${S3_NOTIFICATION_CONFIGURATION}"

if [ $? -ne 0 ]; then
  echo "Failed to configure S3 bucket notifications."
  exit 1
fi

echo "Successfully configured S3 trigger for Lambda function ${LAMBDA_FUNCTION_NAME}."