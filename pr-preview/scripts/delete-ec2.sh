#!/bin/bash
set -e

PR=$1

if [ -z "$PR" ]; then
  echo "Usage: ./delete-ec2.sh <PR_NUMBER>"
  exit 1
fi

source "$(dirname "$0")/common.env"

INSTANCE_NAME="${TAG_PREFIX}-${PR}"

echo "Deleting EC2: $INSTANCE_NAME"

INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "No instance found for $INSTANCE_NAME"
  exit 0
fi

aws ec2 terminate-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

aws ec2 wait instance-terminated \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

echo "EC2 TERMINATED: $INSTANCE_NAME"
