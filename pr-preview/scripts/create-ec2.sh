#!/bin/bash
set -e

PR=$1
BRANCH=$2
REGION="us-east-1"
AMI="ami-0c398cb65a93047f2"
TYPE="t3.micro"
KEY="new"
SG="sg-0dfdfeed826aa181c"
SUBNET="subnet-0a0c27952b7bab8ee"

NAME="pr-preview-$PR"

EXISTING=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:PR,Values=$PR" \
           "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

[ -n "$EXISTING" ] && exit 0

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $AMI \
  --instance-type $TYPE \
  --key-name $KEY \
  --security-group-ids $SG \
  --subnet-id $SUBNET \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=PR,Value=$PR}]" \
  --user-data file://<(env PR=$PR BRANCH=$BRANCH envsubst < pr-preview/scripts/user-data.sh) \
  --query "Instances[0].InstanceId" \
  --output text)

aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID
