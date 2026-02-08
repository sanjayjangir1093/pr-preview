#!/bin/bash
set -e

PR=$1
if [ -z "$PR" ]; then
  echo "Usage: $0 <PR_NUMBER>"
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
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile Name=pr-preview-ec2-role \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Instance ID: $INSTANCE_ID"

aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

echo "Instance running, deploying..."

aws ssm send-command \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters commands=["curl -s https://raw.githubusercontent.com/sanjayjangir1093/pr-preview/main/pr-preview/scripts/deploy.sh | bash"] \
  --comment "Deploy Django PR Preview"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Preview Ready Soon → http://$PUBLIC_IP"
