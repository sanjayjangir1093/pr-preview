#!/bin/bash

PR=$1

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:PR,Values=$PR" "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -n "$IDS" ]; then
  aws ec2 terminate-instances --instance-ids $IDS
  echo "Deleted EC2 for PR $PR"
else
  echo "No EC2 found for PR $PR"
fi
