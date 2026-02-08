<<<<<<< HEAD
name: Delete PR Preview EC2

on:
  pull_request:
    types: [closed]

jobs:
  delete:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Make scripts executable
        run: chmod +x pr-preview/scripts/*.sh

      - name: Delete EC2 Instance
        run: pr-preview/scripts/delete-ec2.sh ${{ github.event.number }}
=======

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
>>>>>>> f5e100f (efefe)
