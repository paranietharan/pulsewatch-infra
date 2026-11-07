# Reproducible validation

Terraform provider lockfiles are committed for both `terraform/` and `terraform/backend_setup/`, including Linux amd64 and macOS arm64 checksums. Provider major versions remain unchanged. Run these commands in each directory:

```sh
terraform fmt -check
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

These checks need no AWS credentials and do not connect to remote state or apply infrastructure. Update providers deliberately using `terraform init -backend=false -upgrade`, review the plan separately, and regenerate lockfile checksums for supported development platforms.

For each Helm values file:

```sh
helm lint helm/pulsewatch -f helm/pulsewatch/values-staging.yaml
helm template review helm/pulsewatch -f helm/pulsewatch/values-staging.yaml
```

CI repeats formatting, validation and Helm rendering for default, staging and production values. Validation does not prove that a deployment will succeed against a particular AWS account or existing state.

## Deployment follow-ups

- The application deployment workflow already supplies commit-based tags for selected services. The chart's mutable fallback tags must be replaced by a complete environment release manifest before removing those defaults; partial deployments must retain the previous immutable tags for unchanged services.
- Migrate DynamoDB locking to S3 `use_lockfile` in a separate backend migration. Require Terraform >=1.10 for all writers, grant GetObject/PutObject/DeleteObject on the state `.tflock` object, retain existing DynamoDB permissions during transition, and verify concurrent-lock behavior before removing the old table. This PR does not change remote locking.
- The current RDS backup default is zero. Choose nonzero retention and review costs/recovery needs before a production apply; zero disables automated backups.
- RabbitMQ 3.13 and provider major upgrades need a coordinated migration and rollback plan. No data volumes, Terraform state or live services are modified by validation.
