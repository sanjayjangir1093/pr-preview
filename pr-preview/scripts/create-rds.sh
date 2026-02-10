#!/bin/bash
set -e

PR=$1

REGION="us-east-1"
SNAPSHOT_ID="temp"                    # ✅ your snapshot name
ENGINE="mysql"
DB_INSTANCE_CLASS="db.t3.micro"
DB_SUBNET_GROUP="default"             # change ONLY if you use custom subnet group
SG_ID="sg-XXXXXXXXXXXX"               # 🔴 RDS security group
TAG_PREFIX="pr-preview-db"

DB_ID="${TAG_PREFIX}-${PR}"

echo "Checking RDS for PR $PR..."

EXISTING=$(aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBInstanceIdentifier=='$DB_ID'].DBInstanceIdentifier" \
  --output text)

if [ -n "$EXISTING" ]; then
  echo "RDS already exists: $DB_ID"
  exit 0
fi

echo "Restoring RDS from snapshot: $SNAPSHOT_ID"

aws rds restore-db-instance-from-db-snapshot \
  --region $REGION \
  --db-instance-identifier $DB_ID \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --db-instance-class $DB_INSTANCE_CLASS \
  --engine $ENGINE \
  --db-subnet-group-name $DB_SUBNET_GROUP \
  --vpc-security-group-ids $SG_ID \
  --no-publicly-accessible \
  --tags Key=Name,Value=$DB_ID Key=PR,Value=$PR

echo "Waiting for RDS to be available..."
aws rds wait db-instance-available \
  --region $REGION \
  --db-instance-identifier $DB_ID

ENDPOINT=$(aws rds describe-db-instances \
  --region $REGION \
  --db-instance-identifier $DB_ID \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "===================================="
echo "🛢️ RDS PREVIEW READY"
echo "PR NUMBER : $PR"
echo "DB ID     : $DB_ID"
echo "ENDPOINT  : $ENDPOINT"
echo "PORT      : 3306"
echo "DB NAME   : temp"
echo "USER      : admin"
echo "===================================="
