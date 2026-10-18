# Yash Desai — AWS portfolio deployment

The complete source for your portfolio, including the light/dark theme button, résumé download, and professional links. This website is plain HTML, CSS, and JavaScript; it does not require an application server or a build step.

## What AWS will host

S3 stores the files in a private, encrypted bucket in `ca-central-1` (Canada Central) by default. CloudFront serves the website over HTTPS and reads S3 through signed Origin Access Control requests. HTTP visitors are redirected to HTTPS.

**The CloudFront website is public, including the downloadable résumé.** The S3 bucket itself remains private. Running the deployment creates AWS resources in your account; AWS usage charges depend on your plan and traffic.

No domain purchase is required. Your first URL will look like `https://d123example.cloudfront.net`. The existing hosted website is not changed by this package.

## Files

| File | Purpose |
| --- | --- |
| `site/index.html` | Portfolio content and page structure |
| `site/styles.css` | Responsive light and dark themes |
| `site/theme.js` | Theme preference and toggle behavior |
| `site/assets/` | Résumé PDF and favicon |
| `infrastructure/cloudformation.json` | S3, CloudFront, access control, caching, and response headers |
| `deploy.sh` | Creates or updates infrastructure, uploads files, and refreshes the CDN |
| `tools/prepare_site.py` | Stages files and sets the website's canonical and sharing URLs |

## 1. Install and authenticate

Install [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and Python 3. Use Terminal on macOS/Linux, AWS CloudShell, or WSL/Git Bash with Python 3 on Windows.

Configure a named AWS profile locally:

```bash
aws configure --profile portfolio
```

Use an IAM role or user allowed to manage CloudFormation stacks, S3 buckets/policies/objects, and CloudFront distributions, origin access controls, cache policies, response header policies, and invalidations. The template does not create IAM users or roles. If your account uses IAM Identity Center, use `aws configure sso --profile portfolio` and `aws sso login --profile portfolio` instead.

Verify the intended account:

```bash
aws sts get-caller-identity --profile portfolio
```

Credentials stay in your AWS configuration; do not put them in the website files.

## 2. Deploy

Unzip the package, open Terminal in the `yash-desai-aws` folder, and run:

```bash
AWS_PROFILE=portfolio AWS_REGION=ca-central-1 bash deploy.sh
```

The script:

1. Confirms your authenticated AWS account and validates the template with AWS.
2. Creates or updates the `yash-desai-portfolio` CloudFormation stack.
3. Creates a temporary copy of the site with your CloudFront URL in the metadata.
4. Uploads the assets, then publishes `index.html` last.
5. Invalidates the CloudFront cache and waits for the refresh.
6. Prints your public HTTPS website URL.

The first run can take several minutes while CloudFront provisions. Let it finish. The script uses AWS's normal deployment and invalidation waiters; a timeout does not necessarily mean the resources failed. Check the named CloudFormation stack or CloudFront invalidation before retrying. Rerun with the same profile, region, and stack name to continue an existing successful stack.

To use a different stack name:

```bash
AWS_PROFILE=portfolio AWS_REGION=ca-central-1 bash deploy.sh my-portfolio
```

Using a new stack name, region, or account creates a separate deployment.

## 3. Update your website

Edit files inside `site/`, then run the same deployment command again. The script handles a CloudFormation "no changes" result and still uploads the updated website. It removes stale objects only from the dedicated bucket created by this stack.

Assets have a five-minute browser cache. `index.html` is uploaded with `no-cache`; the deploy also requests a CloudFront invalidation. Visitors with an existing tab may need to reload it.

You can preview your files on your own computer before deploying:

```bash
python3 -m http.server 8000 --directory site
```

Then open `http://localhost:8000`. The exported source uses an example sharing URL; the deployment replaces it with your actual CloudFront URL automatically.

## Troubleshooting

- **AccessDenied:** verify the selected profile/account and the permissions described above. Keep S3 Block Public Access enabled; public bucket access is not required.
- **CloudFormation failed:** open the stack's Events tab for the failing resource. Resolve the reported permission, quota, or configuration issue. If an initial create ends in `ROLLBACK_COMPLETE`, delete the failed stack before recreating it; inspect any retained bucket before removal.
- **CloudFront initially returns 403:** wait until deployment, upload, and cache invalidation all finish. Confirm `index.html` exists in the bucket and the bucket policy references the correct distribution.
- **Old assets:** wait up to five minutes or reload without cache after the invalidation completes.
- **Adding external scripts, analytics, or fonts:** update the Content Security Policy in the CloudFormation template to permit the specific required origins.

## Remove the AWS deployment

The bucket has `DeletionPolicy: Retain`, so deleting the stack preserves the website files. First record the bucket name:

```bash
aws cloudformation describe-stacks \
  --profile portfolio --region ca-central-1 \
  --stack-name yash-desai-portfolio \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue | [0]" \
  --output text
```

To stop serving the site, delete the stack and wait for completion:

```bash
aws cloudformation delete-stack \
  --profile portfolio --region ca-central-1 \
  --stack-name yash-desai-portfolio

aws cloudformation wait stack-delete-complete \
  --profile portfolio --region ca-central-1 \
  --stack-name yash-desai-portfolio
```

The retained private bucket still uses storage. When you no longer need its contents, remove it from the S3 console. Deleting the stack does not remove files someone already downloaded.

## Validation and limits

The package was checked locally for valid JSON and HTML structure, asset links, JavaScript and shell syntax, CloudFormation reference consistency, and deployment command flow using a simulated AWS CLI. It has not been deployed or AWS-validated in your account. The script runs `cloudformation validate-template` during your actual deployment. No AWS credentials or generated resource IDs are included in the package.

## AWS documentation

- [CloudFront Origin Access Control for private S3 origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [CloudFormation deploy command](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy.html)
- [S3 sync command](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html)
- [CloudFront cache invalidation](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/create-invalidation.html)
