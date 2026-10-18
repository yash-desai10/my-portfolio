#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-ca-central-1}}"
stack_name="${1:-yash-desai-portfolio}"

usage() {
  printf 'Usage: AWS_PROFILE=portfolio AWS_REGION=ca-central-1 bash deploy.sh [stack-name]\n'
}
if [[ "$stack_name" == '--help' || "$stack_name" == '-h' ]]; then
  usage
  exit 0
fi
if [[ $# -gt 1 || ! "$stack_name" =~ ^[A-Za-z][A-Za-z0-9-]{0,127}$ ]]; then
  usage >&2
  printf 'Stack names must start with a letter and contain only letters, digits or hyphens (128 characters maximum).\n' >&2
  exit 1
fi
for dependency in aws python3; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Missing dependency: %s. See README.md.\n' "$dependency" >&2
    exit 1
  fi
done
if [[ "$(aws --version 2>&1)" != aws-cli/2.* ]]; then
  printf 'AWS CLI version 2 is required. See README.md.\n' >&2
  exit 1
fi
if [[ ! -f "$project_root/site/index.html" ]]; then
  printf 'Missing site/index.html. Run this script from the complete downloaded package.\n' >&2
  exit 1
fi
aws_cmd() {
  command aws --region "$deploy_region" --no-cli-pager "$@"
}
get_output() {
  local result
  result="$(aws_cmd cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" \
    --output text)"
  if [[ -z "$result" || "$result" == 'None' || "$result" == 'null' ]]; then
    printf 'Missing CloudFormation output: %s\n' "$1" >&2
    return 1
  fi
  printf '%s' "$result"
}

account_id="$(aws_cmd sts get-caller-identity --query Account --output text)"
printf 'AWS account: %s\nRegion: %s\nStack: %s\n' "$account_id" "$deploy_region" "$stack_name"
printf 'Creating or updating private S3 storage and the public CloudFront website...\n'
aws_cmd cloudformation validate-template \
  --template-body "file://$project_root/infrastructure/cloudformation.json" >/dev/null
aws_cmd cloudformation deploy \
  --template-file "$project_root/infrastructure/cloudformation.json" \
  --stack-name "$stack_name" \
  --no-fail-on-empty-changeset \
  --tags Project=yash-desai-portfolio

bucket_name="$(get_output BucketName)"
distribution_id="$(get_output DistributionId)"
website_url="$(get_output WebsiteUrl)"
staging_directory="$(mktemp -d)"
trap 'rm -rf -- "$staging_directory"' EXIT
python3 "$project_root/tools/prepare_site.py" "$project_root/site" "$staging_directory" "$website_url"

printf 'Uploading the website files...\n'
# This bucket belongs to this stack. Remove stale files, then publish HTML last.
aws_cmd s3 sync "$staging_directory/" "s3://$bucket_name/" \
  --delete --exclude 'index.html' \
  --cache-control 'public,max-age=300' \
  --only-show-errors
aws_cmd s3 cp "$staging_directory/index.html" "s3://$bucket_name/index.html" \
  --content-type 'text/html; charset=utf-8' \
  --cache-control 'no-cache' \
  --only-show-errors

printf 'Refreshing the CloudFront cache...\n'
invalidation_id="$(aws_cmd cloudfront create-invalidation \
  --distribution-id "$distribution_id" \
  --paths '/*' --query 'Invalidation.Id' --output text)"
if ! aws_cmd cloudfront wait invalidation-completed \
  --distribution-id "$distribution_id" --id "$invalidation_id"; then
  printf 'Files were uploaded. Cache refresh is still pending or its waiter failed.\n' >&2
  printf 'Check distribution %s, invalidation %s in CloudFront.\n' "$distribution_id" "$invalidation_id" >&2
  exit 1
fi
printf '\nWebsite deployed: %s\nBucket: %s\nCloudFront distribution: %s\n' "$website_url" "$bucket_name" "$distribution_id"
