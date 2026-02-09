#!/bin/bash
set -e

PR=$1

if [ -z "$PR" ]; then
  echo "Usage: ./create-ec2.sh <PR_NUMBER>"
  exit 1
fi

source "$(dirname "$0")/common.env"

INSTANCE_NAME="${TAG_PREFIX}-${PR}"

echo "Creating EC2: $INSTANCE_NAME"

INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

EC2_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "EC2 READY: $EC2_IP"
