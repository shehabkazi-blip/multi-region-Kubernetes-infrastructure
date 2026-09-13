# On-Demand Provision, Test & Destroy — setup notes

File: `.github/workflows/ondemand-provision-teardown.yml`

## What it does

Manually triggered from the **Actions** tab (`workflow_dispatch`). You pick:
- **target_region**: `region-a`, `region-b`, or `both`
- **skip_destroy**: leave it unchecked (default) for the normal flow

Pipeline:
1. **provision-and-test** — `terraform apply` in `environments/<region>`, updates
   kubeconfig, deploys the sample app via the Kustomize production overlay
   (`k8s/overlays/production/<region>`), waits for rollout, then hits
   `/healthz` through the ALB a few times with retries.
2. **destroy** — runs afterwards **regardless of whether step 1 passed or
   failed** (`if: always()`), unless you ticked `skip_destroy`. This is the
   safety net: a failed health check still tears down the infra instead of
   leaving it running (and billing) unattended.

If `target_region: both` is selected, both regions run as a matrix — each
region provisions/tests/destroys independently, so a failure in one doesn't
block cleanup of the other.

## One-time setup required

1. **OIDC role in AWS** — this workflow assumes AWS credentials via GitHub's
   OIDC provider (no long-lived access keys). Create an IAM role trusted by
   `token.actions.githubusercontent.com` for your repo, with permissions to
   manage VPC/EKS/IAM resources your Terraform modules create, plus
   `eks:DescribeCluster` / `eks:*` for `update-kubeconfig` and enough RBAC on
   the cluster (via the EKS access entry / aws-auth) to `kubectl apply`.
   Store the role ARN as the repo secret **`AWS_DEPLOY_ROLE_ARN`**.

   If you'd rather use static credentials during initial testing, swap the
   `aws-actions/configure-aws-credentials@v4` step's `role-to-assume` input
   for `aws-access-key-id` / `aws-secret-access-key` secrets — but move to
   OIDC before this touches real production accounts.

2. **Cluster names** — the workflow guesses cluster names via
   `REGION_A_CLUSTER_NAME` / `REGION_B_CLUSTER_NAME` env vars at the top of
   the file. Update these to match whatever `modules/eks` actually names your
   clusters (check the module's `cluster_name` output).

3. **Terraform backend** — `environments/region-a/backend.tf` and
   `environments/region-b/backend.tf` must already point at remote state
   (S3 + DynamoDB lock table, most likely, given your existing setup) so
   `terraform init` in CI has something to attach to. No changes needed here
   if that's already configured.

4. **AWS Load Balancer Controller** must be installed on each cluster (via
   Terraform/Helm as part of your EKS module, or a separate bootstrap step)
   for the Ingress health check step to get an ALB hostname at all.

## Cleanup order matters — why the destroy job deletes the app first

The AWS Load Balancer Controller provisions the ALB directly against the AWS
API — it is **not** tracked in Terraform state. If `terraform destroy` runs
while the Ingress (and its ALB) still exists, the ALB's ENIs are still
attached to your VPC's subnets, and Terraform's attempt to delete the VPC
fails with a dependency-violation error — leaving a half-destroyed
environment running (and billing) instead of a clean teardown.

The `destroy` job accounts for this: it updates kubeconfig, runs
`kubectl delete -k k8s/overlays/production/<region>` to let the controller
deprovision the ALB properly, waits ~45s for that to finish, and only then
runs `terraform destroy`. Both of those steps use `continue-on-error: true`
so a cluster that's already partially gone doesn't block the rest of
cleanup.

**Still worth doing manually after any live test**, especially before/after
recording a demo: check the AWS console (or `aws eks list-clusters --region
<region>` / `aws ec2 describe-vpcs --region <region>`) in both regions to
confirm nothing is left running. Auto-cleanup is a safety net, not a
guarantee — a GitHub Actions runner dying mid-job, or an API throttling
error, can still leave something behind.

## Notes / things worth deciding on purpose

- **Concurrency lock** — the workflow uses a concurrency group per region so
  two runs can't fight over the same Terraform state file at once.
- **skip_destroy** exists for when you want to leave a region up to poke
  around manually — remember to destroy it yourself afterwards if you use it.
- This workflow does not `terraform plan` for review first — it applies
  directly, since the whole point is a self-contained provision → test →
  destroy loop kicked off on demand. If you want a plan-then-approve gate
  instead, that's a reasonable variant to add (e.g. an `environment:` with
  required reviewers on the `provision-and-test` job).
