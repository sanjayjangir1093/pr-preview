#!/bin/bash
set -e

PR=$1

REGION="ap-south-1"
AMI_ID="ami-0c398cb65a93047f2"     # Ubuntu 22.04 AMI
INSTANCE_TYPE="t3.micro"
KEY_NAME="new.pem"
SG_ID="sg-0dfdfeed826aa181c"
SUBNET_ID="subnet-0a0c27952b7bab8ee"

if [ -z "$PR" ]; then
  echo "Usage: ./create-ec2.sh <PR_NUMBER>"
  exit 1
fi

echo "Creating EC2 for PR-$PR..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=pr-preview-$PR}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "EC2 Instance ID: $INSTANCE_ID"

aws ec2 wait instance-running \
  --region $REGION \
  --instance-ids $INSTANCE_ID

EC2_IP=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "EC2 READY"
echo "Public IP: $EC2_IP"
