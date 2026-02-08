#!/bin/bash
set -e

PR=$1
REGION="ap-south-1"

if [ -z "$PR" ]; then
  echo "Usage: ./delete-ec2.sh <PR_NUMBER>"
  exit 1
fi

echo "Deleting EC2 for PR-$PR..."

INSTANCE_ID=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=pr-preview-$PR" "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "No instance found for PR-$PR"
  exit 0
fi

aws ec2 terminate-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID

echo "EC2 terminated: $INSTANCE_ID"
