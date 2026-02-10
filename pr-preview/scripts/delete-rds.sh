#!/bin/bash
set -e

PR=$1
REGION="us-east-1"
TAG_PREFIX="pr-preview-db"

DB_ID="${TAG_PREFIX}-${PR}"

echo "Deleting RDS: $DB_ID"

EXISTING=$(aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBInstanceIdentifier=='$DB_ID'].DBInstanceIdentifier" \
  --output text)

if [ -z "$EXISTING" ]; then
  echo "No RDS found for $DB_ID"
  exit 0
fi

aws rds delete-db-instance \
  --region $REGION \
  --db-instance-identifier $DB_ID \
  --skip-final-snapshot

aws rds wait db-instance-deleted \
  --region $REGION \
  --db-instance-identifier $DB_ID

echo "🗑️ RDS DELETED: $DB_ID"
