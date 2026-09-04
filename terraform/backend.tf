# ==============================================================================
# AWS S3 State Backend (No DynamoDB Required)
# Uses Amazon S3 for remote state storage
# ==============================================================================

terraform {
  backend "s3" {
    # Configuration is supplied dynamically via CLI or GitHub Actions:
    #   terraform init \
    #     -backend-config="bucket=${BUCKET_NAME}" \
    #     -backend-config="key=environments/${ENV}/terraform.tfstate" \
    #     -backend-config="region=${AWS_REGION}"
  }
}
