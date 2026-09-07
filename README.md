# Secure Terraform AWS Baseline

[![Terraform Security Baseline](https://github.com/aodare/secure-terraform-aws-baseline/actions/workflows/terraform-security.yml/badge.svg)](https://github.com/aodare/secure-terraform-aws-baseline/actions/workflows/terraform-security.yml)

A security-focused AWS Terraform baseline that demonstrates hardened Amazon S3 storage, customer-managed KMS encryption, least-privilege-aware key policies, automated infrastructure validation, and Checkov security scanning in GitHub Actions.

This project is designed as a safe DevSecOps portfolio lab. It can be formatted, validated, and statically scanned without AWS credentials, an AWS account, Terraform state, or any cloud deployment.

## Project Goals

- Define secure S3 storage controls as infrastructure as code.
- Apply security checks before deployment through automated CI.
- Demonstrate that a hardened baseline passes static security scanning.
- Demonstrate that an intentionally insecure S3 configuration is detected.
- Keep AWS credentials, Terraform state, account-specific values, and deployments out of the repository and CI workflow.

## Architecture

```text
GitHub Push or Pull Request
           |
           v
GitHub Actions CI
           |
           +--> terraform fmt -check
           |
           +--> terraform init -backend=false
           |
           +--> terraform validate
           |
           +--> Checkov scan: secure Terraform baseline must pass
           |
           +--> Checkov scan: insecure training fixture must fail
           |
           v
JSON scan reports uploaded as workflow artifacts
```

## Security Controls

| Control | Implementation | Security value |
|---|---|---|
| Public-access prevention | S3 Block Public Access is enabled for the data and access-log buckets. | Prevents common public ACL and bucket-policy exposure paths. |
| Versioning | S3 versioning is enabled for the data and logging buckets. | Supports recovery after accidental deletion or overwrite. |
| Encryption at rest | S3 default encryption uses a customer-managed AWS KMS key. | Provides encryption control and auditable key usage. |
| KMS key rotation | KMS rotation is enabled. | Reduces long-term cryptographic key exposure. |
| Explicit KMS key policy | The KMS policy is declared in Terraform. | Makes key access design reviewable and version-controlled. |
| S3 access logging | The data bucket sends access logs to a dedicated log bucket. | Provides visibility into bucket request activity. |
| Log protection | The log bucket has encryption, versioning, public-access blocking, and lifecycle retention. | Helps protect audit data and manage retention. |
| Lifecycle controls | Old noncurrent versions transition/expire, and incomplete multipart uploads are aborted. | Improves recovery, reduces stale data, and limits storage waste. |
| Resource tags | Resources include environment, ownership, management, and purpose tags. | Supports governance, inventory, and operational accountability. |
| CI security gate | Checkov scans the secure baseline in GitHub Actions. | Detects configuration risks before deployment. |
| Detection test | A purposely insecure public S3 fixture is scanned separately. | Confirms the scanner can detect insecure infrastructure. |

Amazon S3 Block Public Access can override public S3 permissions at the bucket or account level. S3 versioning supports restoring objects that are accidentally deleted or overwritten, and AWS recommends monitoring S3 access with CloudTrail or S3 server access logs. [AWS S3 security features](https://aws.amazon.com/s3/security/)

## Repository Structure

```text
secure-terraform-aws-baseline/
├── .github/
│   └── workflows/
│       └── terraform-security.yml
├── insecure-examples/
│   └── public-s3-bucket.tf
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── .gitignore
└── README.md
```

## Secure Baseline

The `terraform/` directory defines:

- A primary S3 data bucket.
- A dedicated S3 access-log bucket.
- Public Access Block for both buckets.
- Versioning for both buckets.
- Default SSE-KMS encryption using a customer-managed KMS key.
- A KMS alias and explicit key policy.
- A lifecycle configuration for noncurrent object versions and incomplete multipart uploads.
- Access-log retention through a lifecycle rule.
- Input-variable validation and non-sensitive Terraform outputs.

### KMS key policy approach

The KMS key policy uses Terraform’s `aws_caller_identity` data source to reference the active account dynamically:

```hcl
AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
```

No AWS account ID is hardcoded in the repository. In a KMS key policy, the account principal enables authorized IAM policies in that account to grant access; it does not mean the root-user login should be used for routine operations.

The policy also restricts listed cryptographic operations to S3 service requests in the configured Region using:

```hcl
"kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
```

AWS KMS key policies are resource-based policies that control access to individual KMS keys. [AWS KMS key-policy overview](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html)

## Insecure Training Fixture

The file below is intentionally unsafe and must never be deployed:

```text
insecure-examples/public-s3-bucket.tf
```

It creates an S3 bucket with a `public-read` ACL and omits key security controls such as Public Access Block, versioning, and explicit default encryption.

The CI workflow scans this fixture in report-only/detection-test mode. The fixture is expected to produce Checkov findings; the workflow fails only if it unexpectedly passes.

## CI Workflow

The GitHub Actions workflow is located at:

```text
.github/workflows/terraform-security.yml
```

### Secure-baseline job

This job must pass:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

It then runs Checkov against `terraform/` and uploads a JSON report artifact.

### Insecure-fixture job

This job scans `insecure-examples/` with Checkov. The scan is expected to find problems. The workflow records that expected detection and uploads its JSON report as an artifact.

### Checkov exceptions

Two Checkov checks are intentionally skipped for this focused single-region portfolio baseline:

| Check | Reason for scoped exception |
|---|---|
| `CKV2_AWS_62` — S3 event notifications | Notifications need an operational destination such as EventBridge, SNS, SQS, or Lambda. Those components are intentionally out of scope for this storage-baseline demonstration. |
| `CKV_AWS_144` — Cross-Region Replication | Replication requires a destination bucket, replication IAM role, cross-Region design, recovery objectives, and cost planning. It is not appropriate to enable by default for every sandbox bucket. |

All other detected Checkov issues remain blocking for the secure baseline.

## Local Validation

No AWS credentials are required for local formatting, validation, or static analysis.

### Prerequisites

- Terraform 1.6 or later
- Optional: Checkov, if you want to run local security scanning

### Format and validate

```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Scan the secure baseline

If Checkov is installed:

```bash
checkov -d terraform --framework terraform
```

### Scan the insecure fixture

```bash
checkov -d insecure-examples --framework terraform
```

The insecure scan is expected to report failures.

### Important deployment warning

Do **not** run the following command unless you have reviewed the code, configured an authorized sandbox AWS account, understand the cost and security implications, and have an approved state-management design:

```bash
terraform apply
```

This repository has no remote backend configuration and CI does not run a plan or apply.

## Variables

A safe variables template is included:

```text
terraform/terraform.tfvars.example
```

Copy it locally if needed:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Do not commit a real `terraform.tfvars` file if it contains account-specific, internal, or sensitive values.

## Workflow Artifacts

After a successful GitHub Actions run, open the workflow run page and download:

```text
secure-baseline-checkov-report
insecure-fixture-checkov-report
```

These JSON artifacts show:

- The passing security scan for the hardened Terraform baseline.
- The detected security findings for the deliberately insecure S3 fixture.

## Skills Demonstrated

- Terraform infrastructure as code
- AWS S3 security controls
- AWS KMS encryption and key-policy design
- Secure S3 access logging and lifecycle management
- Infrastructure validation with `terraform fmt` and `terraform validate`
- Checkov IaC security scanning
- GitHub Actions CI/CD and workflow artifacts
- Policy-as-code and shift-left security practices
- Secure handling of Terraform state, variables, credentials, and deployment boundaries
- Cloud-security documentation and risk-based exception handling

## Important Limitations

This repository is a learning and portfolio baseline, not a complete production architecture.

It does not include:

- A remote Terraform state backend, locking, or a production state-management strategy.
- A fully designed KMS administration, key-usage, break-glass, or cross-account access model.
- S3 event notification destinations, SIEM integration, or alerting workflows.
- Cross-Region Replication, disaster-recovery objectives, or multi-Region failover design.
- VPC endpoints, network controls, data classification, object lock, backup policy, or organization-wide guardrails.
- A live AWS deployment or real cloud account data.

Review and adapt all controls, policies, cost settings, retention periods, and exception decisions for the organization and workload before any deployment.
