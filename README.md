# multi-region-k8s-infrastructure

Terraform + Kubernetes infrastructure for a two-region EKS setup (Region A =
`us-east-1`, Region B = `eu-west-1`), plus a sample app to validate both
clusters end-to-end.

## Structure

```
.
├── modules/
│   ├── vpc/            # multi-AZ VPC, public/private subnets, NAT
│   ├── eks/             # EKS cluster, managed node group, OIDC provider
│   └── lb-controller/   # AWS Load Balancer Controller (IRSA + Helm)
├── environments/
│   ├── region-a/         # us-east-1 — wires vpc + eks + lb-controller
│   └── region-b/         # eu-west-1 — same, different region
├── app/                  # sample Node.js/Express service
├── k8s/                  # Kustomize base + production overlays
├── helm/                 # Helm chart alternative to k8s/
├── .github/workflows/
│   ├── terraform-ci.yml               # fmt/validate/plan on PR
│   └── ondemand-provision-teardown.yml # manual apply → test → destroy
└── DEPLOY_INSTRUCTIONS.md
```

## First-time setup

1. **Remote state** — create an S3 bucket + DynamoDB lock table, then fill in
   `environments/region-a/backend.tf` and `environments/region-b/backend.tf`
   (`<YOUR_TFSTATE_BUCKET>`, `<YOUR_TF_LOCK_TABLE>`).
2. **GitHub secret** — add `AWS_DEPLOY_ROLE_ARN` (an OIDC-federated IAM role
   GitHub Actions can assume) under repo Settings → Secrets and variables →
   Actions.
3. **Image placeholders** — replace `<ACCOUNT_ID>` in
   `k8s/overlays/production/*/kustomization.yaml` and
   `helm/sample-app/values-region-*.yaml` with your real AWS account ID.

## Provisioning

```bash
cd environments/region-a
terraform init
terraform plan
terraform apply
```

Repeat in `environments/region-b`. See `DEPLOY_INSTRUCTIONS.md` for building
the app image and deploying it to both clusters, and
`.github/workflows/README-ondemand.md` for the one-click provision → test →
destroy pipeline.

See `DOCUMENTATION.md` for a deeper explanation of each module and design
decision.
