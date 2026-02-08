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
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --iam-instance-profile Name=pr-preview-ec2-role \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Valu]()

# Launch EC2
INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --iam-instance-profile Name=pr-preview-ec2-role \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Waiting for EC2 to run..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

# Wait for public IP
for i in {1..20}; do
    EC2_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    if [ "$EC2_IP" != "None" ]; then
        break
    fi
    echo "Waiting for public IP..."
    sleep 6
done

echo "EC2 READY: $EC2_IP"

# Install SSM agent via SSM (Ubuntu)
aws ssm send-command \
  --targets "Key=instanceIds,Values=$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Install SSM Agent" \
  --parameters 'commands=["sudo apt update && sudo apt install -y snapd && sudo snap install amazon-ssm-agent --classic && sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service && sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service"]' \
  --region "$REGION"

echo "SSM Agent installation triggered on EC2: $EC2_IP"
