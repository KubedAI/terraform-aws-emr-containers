#!/usr/bin/env bash
# Simple EMR on EKS submit example (no verification loop).
#
# Fill these values before running:
#   TEAM
#   VIRTUAL_CLUSTER_ID
#   EXECUTION_ROLE_ARN
#
# Usage:
#   ./validate-emr-on-eks.sh <path-to-terraform-example>
#
# Examples:
#   TEAM=analytics ./validate-emr-on-eks.sh ../basic
#   TEAM=datateam-a ./validate-emr-on-eks.sh ../deploy-without-eks-access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# First positional arg = path to the Terraform example that holds state.
# Defaults to examples/basic (original location).
STACK_DIR="${1:-${SCRIPT_DIR}/../basic}"
STACK_DIR="$(cd "${STACK_DIR}" && pwd)"

TEAM="${TEAM:-analytics}"
RELEASE_LABEL="${RELEASE_LABEL:-emr-7.12.0-latest}"

VIRTUAL_CLUSTER_ID="$(terraform -chdir="${STACK_DIR}" output -json virtual_clusters | jq -r ".[\"${TEAM}\"].id")"
EXECUTION_ROLE_ARN="$(terraform -chdir="${STACK_DIR}" output -json job_execution_role_arns | jq -r ".[\"${TEAM}\"]")"

echo "TEAM=${TEAM}"
echo "VIRTUAL_CLUSTER_ID=${VIRTUAL_CLUSTER_ID}"
echo "EXECUTION_ROLE_ARN=${EXECUTION_ROLE_ARN}"

if [[ -z "${VIRTUAL_CLUSTER_ID}" || "${VIRTUAL_CLUSTER_ID}" == "null" || -z "${EXECUTION_ROLE_ARN}" || "${EXECUTION_ROLE_ARN}" == "null" ]]; then
  echo "Could not resolve Terraform outputs for TEAM='${TEAM}' from ${STACK_DIR}." >&2
  exit 1
fi


JOB_NAME="sparkpi-${TEAM}-$(date +%Y%m%d%H%M%S)"
LOG_GROUP="$(terraform -chdir="${STACK_DIR}" output -json cloudwatch_log_groups | jq -r ".[\"${TEAM}\"].name")"
LOG_PREFIX="sparkpi"

echo "Submitting EMR on EKS job..."
START_OUTPUT="$(
  aws emr-containers start-job-run \
    --virtual-cluster-id "${VIRTUAL_CLUSTER_ID}" \
    --name "${JOB_NAME}" \
    --execution-role-arn "${EXECUTION_ROLE_ARN}" \
    --release-label "${RELEASE_LABEL}" \
    --job-driver '{
      "sparkSubmitJobDriver": {
        "entryPoint": "local:///usr/lib/spark/examples/jars/spark-examples.jar",
        "entryPointArguments": ["5000"],
        "sparkSubmitParameters": "--class org.apache.spark.examples.SparkPi --conf spark.executor.instances=2"
      }
    }' \
    --configuration-overrides "{
      \"monitoringConfiguration\": {
        \"cloudWatchMonitoringConfiguration\": {
          \"logGroupName\": \"${LOG_GROUP}\",
          \"logStreamNamePrefix\": \"${LOG_PREFIX}\"
        }
      }
    }"
)"

JOB_RUN_ID="$(jq -r '.id' <<<"${START_OUTPUT}")"

echo "Submitted job run ID: ${JOB_RUN_ID}"
echo "Check status:"
echo "aws emr-containers describe-job-run --id \"${JOB_RUN_ID}\" --virtual-cluster-id \"${VIRTUAL_CLUSTER_ID}\" --query 'jobRun.state' --output text"
