#!/bin/bash
set -e

PR=$1
REGION=us-east-1
AMI=ami-0fc5d935ebf8bc3bc   # Amazon Linux 2 (SSM supported)
TYPE=t3.micro
NAME=pr-preview-$PR

echo "Creating EC2: $NAME"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI \
  --instance-type $TYPE \
  --region $REGION \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=PR,Value=$PR}]" \
  --iam-instance-profile Name=EC2SSMRole \
  --security-group-ids sg-0dfdfeed826aa181c \
  --subnet-id subnet-0a0c27952b7bab8ee \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "EC2 READY $IP"
