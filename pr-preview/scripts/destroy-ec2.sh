#!/bin/bash
set -e

PR=$1

echo "Destroying EC2 for PR: $PR"

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:PR,Values=$PR" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -z "$IDS" ]; then
  echo "No EC2 found for PR $PR"
  exit 0
fi

aws ec2 terminate-instances --instance-ids $IDS

aws ec2 wait instance-terminated --instance-ids $IDS

echo "EC2 TERMINATED for PR $PR"
