#!/bin/bash
set -e

PR=$1
REGION="us-east-1"
AMI="ami-0c398cb65a93047f2"
TYPE="t3.micro"
KEY="new"
SG="sg-0dfdfeed826aa181c"
SUBNET="subnet-0a0c27952b7bab8ee"

NAME="pr-preview-$PR"

echo "Checking existing EC2 for PR $PR"

EXISTING=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:PR,Values=$PR" \
           "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -n "$EXISTING" ]; then
  echo "EC2 already exists: $EXISTING"
  exit 0
fi

echo "Encoding user-data"
USER_DATA=$(base64 -w 0 pr-preview/scripts/user-data.sh)

echo "Creating EC2: $NAME"

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $AMI \
  --instance-type $TYPE \
  --key-name $KEY \
  --security-group-ids $SG \
  --subnet-id $SUBNET \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=PR,Value=$PR}]" \
  --user-data "$USER_DATA" \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

IP=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "===================================="
echo "🚀 PR PREVIEW READY"
echo "PR NUMBER : $PR"
echo "EC2 IP    : $IP"
echo "APP URL   : http://$IP"
echo "===================================="
