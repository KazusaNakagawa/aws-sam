#!/bin/bash

# Usage: ./setup_s3_trigger.sh <env> <input_bucket_name>
# Example: ./setup_s3_trigger.sh dev input-bucket

# Check if environment argument is provided
if [ -z "$1" ];then
  echo "Environment argument is required."
  echo "Usage: $0 <env> <input_bucket_name>" 
  exit 1
fi

ENV=$1
INPUT_BUCKET_NAME=$2

LAMBDA_EVENTS=(
  "s3-copy-lambda-${ENV}" "${INPUT_BUCKET_NAME}-${ENV}" "input/" ".json"
  "s3-copy-lambda2-${ENV}" "${INPUT_BUCKET_NAME}-${ENV}" "input/prefix/" ".tsv.gz"
)

# 配列の要素数
NUM_ELEMENTS=${#LAMBDA_EVENTS[@]}

# 1タプルあたりの要素数
ELEMENTS_PER_TUPLE=4

# ループでタプルを処理
for ((i=0; i<$NUM_ELEMENTS; i+=$ELEMENTS_PER_TUPLE)); do
  LAMBDA_FUNCTION_NAME=${LAMBDA_EVENTS[i]}
  S3_BUCKET_NAME=${LAMBDA_EVENTS[i+1]}
  S3_PREFIX=${LAMBDA_EVENTS[i+2]}
  S3_SUFFIX=${LAMBDA_EVENTS[i+3]}

  # Get the Lambda function ARN
  LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name ${LAMBDA_FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text)

  if [ -z "$LAMBDA_FUNCTION_ARN" ]; then
    echo "Lambda function ${LAMBDA_FUNCTION_NAME} does not exist."
    exit 1
  fi

  echo "Lambda Function ARN: ${LAMBDA_FUNCTION_ARN}"

  # Generate a unique statement ID using timestamp
  STATEMENT_ID="s3invoke-$(date +%s)"

  # Add permission for S3 to invoke the Lambda function
  aws lambda add-permission --function-name ${LAMBDA_FUNCTION_NAME} --principal s3.amazonaws.com --statement-id ${STATEMENT_ID} --action "lambda:InvokeFunction" --source-arn arn:aws:s3:::${S3_BUCKET_NAME} --source-account $(aws sts get-caller-identity --query Account --output text)

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
  aws s3api put-bucket-notification-configuration --bucket ${S3_BUCKET_NAME} --notification-configuration "$S3_NOTIFICATION_CONFIGURATION"

  if [ $? -ne 0 ]; then
    echo "Failed to configure S3 bucket notifications."
    exit 1
  fi

  echo "Successfully configured S3 trigger for Lambda function ${LAMBDA_FUNCTION_NAME}."
done
