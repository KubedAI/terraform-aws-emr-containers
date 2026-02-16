#!/usr/bin/env bash
# NVMe pod-template EMR on EKS submit example (submit only).
#
# Usage:
#   S3_BUCKET_URI=s3://my-bucket ./execute_emr_eks_job.sh <path-to-terraform-example>
#
# Examples:
#   S3_BUCKET_URI=s3://my-bucket TEAM=analytics ./execute_emr_eks_job.sh ../../basic
#   S3_BUCKET_URI=s3://my-bucket TEAM=datateam-a ./execute_emr_eks_job.sh ../../deploy-without-eks-access
#
# Environment variables:
#   TEAM            - Team name matching a key in the teams map (default: analytics)
#   S3_BUCKET_URI   - S3 bucket for job artifacts and data (required)
#   RELEASE_LABEL   - EMR release label (default: emr-7.12.0-latest)
#   AWS_REGION      - AWS region (default: us-west-2)

set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd aws
require_cmd jq
require_cmd terraform
require_cmd wget

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# First positional arg = path to the Terraform example that holds state.
# Defaults to examples/basic.
STACK_DIR="${1:-${SCRIPT_DIR}/../../basic}"
STACK_DIR="$(cd "${STACK_DIR}" && pwd)"

TEAM="${TEAM:-analytics}"
S3_BUCKET_URI="${S3_BUCKET_URI:-REPLACE_ME}"
RELEASE_LABEL="${RELEASE_LABEL:-emr-7.12.0-latest}"
AWS_REGION="${AWS_REGION:-us-west-2}"

if [[ "${S3_BUCKET_URI}" == "REPLACE_ME" ]]; then
  echo "Set S3_BUCKET_URI before running." >&2
  exit 1
fi

VIRTUAL_CLUSTER_ID="$(terraform -chdir="${STACK_DIR}" output -json virtual_clusters | jq -r ".[\"${TEAM}\"].id")"
NAMESPACE="$(terraform -chdir="${STACK_DIR}" output -json virtual_clusters | jq -r ".[\"${TEAM}\"].namespace")"
EXECUTION_ROLE_ARN="$(terraform -chdir="${STACK_DIR}" output -json job_execution_role_arns | jq -r ".[\"${TEAM}\"]")"

if [[ -z "${VIRTUAL_CLUSTER_ID}" || "${VIRTUAL_CLUSTER_ID}" == "null" || -z "${NAMESPACE}" || "${NAMESPACE}" == "null" || -z "${EXECUTION_ROLE_ARN}" || "${EXECUTION_ROLE_ARN}" == "null" ]]; then
  echo "Could not resolve Terraform outputs for TEAM='${TEAM}' from ${STACK_DIR}." >&2
  exit 1
fi

echo "TEAM=${TEAM}"
echo "VIRTUAL_CLUSTER_ID=${VIRTUAL_CLUSTER_ID}"
echo "NAMESPACE=${NAMESPACE}"
echo "EXECUTION_ROLE_ARN=${EXECUTION_ROLE_ARN}"

JOB_NAME="nvme-ssd-${TEAM}-$(date +%Y%m%d%H%M%S)"
LOG_GROUP="$(terraform -chdir="${STACK_DIR}" output -json cloudwatch_log_groups | jq -r ".[\"${TEAM}\"].name")"
SPARK_JOB_S3_PATH="${S3_BUCKET_URI%/}/${VIRTUAL_CLUSTER_ID}/${JOB_NAME}"
SCRIPTS_S3_PATH="${SPARK_JOB_S3_PATH}/scripts"
INPUT_DATA_S3_PATH="${SPARK_JOB_S3_PATH}/input"
OUTPUT_DATA_S3_PATH="${SPARK_JOB_S3_PATH}/output"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Rendering namespace in pod templates..."
sed -E "s|namespace: .*|namespace: ${NAMESPACE}|" "${SCRIPT_DIR}/pod-templates/driver-pod-template.yaml" > "${TMP_DIR}/driver-pod-template.yaml"
sed -E "s|namespace: .*|namespace: ${NAMESPACE}|" "${SCRIPT_DIR}/pod-templates/executor-pod-template.yaml" > "${TMP_DIR}/executor-pod-template.yaml"

echo "Uploading PySpark script and pod templates to S3..."
aws s3 cp "${SCRIPT_DIR}/pyspark-taxi-trip.py" "${SCRIPTS_S3_PATH}/pyspark-taxi-trip.py" --region "${AWS_REGION}"
aws s3 cp "${TMP_DIR}/driver-pod-template.yaml" "${SCRIPTS_S3_PATH}/driver-pod-template.yaml" --region "${AWS_REGION}"
aws s3 cp "${TMP_DIR}/executor-pod-template.yaml" "${SCRIPTS_S3_PATH}/executor-pod-template.yaml" --region "${AWS_REGION}"

echo "Uploading sample input parquet to S3..."
wget -q "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2022-01.parquet" -O "${TMP_DIR}/yellow_tripdata_2022-01.parquet"
aws s3 cp "${TMP_DIR}/yellow_tripdata_2022-01.parquet" "${INPUT_DATA_S3_PATH}/yellow_tripdata_2022-01.parquet" --region "${AWS_REGION}"

echo "Submitting EMR on EKS NVMe job..."
START_OUTPUT="$(
  aws emr-containers start-job-run \
    --virtual-cluster-id "${VIRTUAL_CLUSTER_ID}" \
    --name "${JOB_NAME}" \
    --region "${AWS_REGION}" \
    --execution-role-arn "${EXECUTION_ROLE_ARN}" \
    --release-label "${RELEASE_LABEL}" \
    --job-driver "{
      \"sparkSubmitJobDriver\": {
        \"entryPoint\": \"${SCRIPTS_S3_PATH}/pyspark-taxi-trip.py\",
        \"entryPointArguments\": [\"${INPUT_DATA_S3_PATH}\", \"${OUTPUT_DATA_S3_PATH}\"]
      }
    }" \
    --configuration-overrides "{
      \"applicationConfiguration\": [
        {
          \"classification\": \"spark-defaults\",
          \"properties\": {
            \"spark.kubernetes.driver.podTemplateFile\": \"${SCRIPTS_S3_PATH}/driver-pod-template.yaml\",
            \"spark.kubernetes.executor.podTemplateFile\": \"${SCRIPTS_S3_PATH}/executor-pod-template.yaml\",
            \"spark.local.dir\": \"/data1\",
            \"spark.dynamicAllocation.enabled\": \"true\",
            \"spark.dynamicAllocation.shuffleTracking.enabled\": \"true\",
            \"spark.dynamicAllocation.minExecutors\": \"2\",
            \"spark.dynamicAllocation.maxExecutors\": \"10\",
            \"spark.dynamicAllocation.initialExecutors\": \"2\",
            \"spark.sql.adaptive.enabled\": \"true\",
            \"spark.sql.adaptive.coalescePartitions.enabled\": \"true\",
            \"spark.sql.adaptive.skewJoin.enabled\": \"true\",
            \"spark.kubernetes.executor.podNamePrefix\": \"${JOB_NAME}\"
          }
        }
      ],
      \"monitoringConfiguration\": {
        \"cloudWatchMonitoringConfiguration\": {
          \"logGroupName\": \"${LOG_GROUP}\",
          \"logStreamNamePrefix\": \"${JOB_NAME}\"
        },
        \"s3MonitoringConfiguration\": {
          \"logUri\": \"${S3_BUCKET_URI%/}/logs/\"
        }
      }
    }"
)"

JOB_RUN_ID="$(jq -r '.id' <<<"${START_OUTPUT}")"

echo "Submitted job run ID: ${JOB_RUN_ID}"
echo "Output path: ${OUTPUT_DATA_S3_PATH}"
echo "Check status:"
echo "aws emr-containers describe-job-run --id \"${JOB_RUN_ID}\" --virtual-cluster-id \"${VIRTUAL_CLUSTER_ID}\" --region \"${AWS_REGION}\" --query 'jobRun.state' --output text"
