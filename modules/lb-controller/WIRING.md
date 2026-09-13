# modules/lb-controller — wiring guide

This module installs the AWS Load Balancer Controller (IRSA role + policy +
Helm release) so `Ingress` objects can actually provision an ALB. Without
this, `kubectl apply -k k8s/overlays/production/<region>` will succeed but
the Ingress will sit forever with no address, and the health-check step in
the on-demand workflow will fail.

## 1. Add the required Terraform providers

Your `environments/region-a/main.tf` (and `region-b`) need the `kubernetes`
and `helm` providers configured to talk to the EKS cluster you just created
— add near wherever the `eks` module is called:

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
```

(Adjust the attribute names — `cluster_endpoint`, `cluster_ca_certificate`,
`cluster_name` — to whatever your actual `modules/eks/outputs.tf` exposes.)

## 2. Make sure modules/eks exposes an OIDC provider

The IRSA trust relationship needs the cluster's OIDC provider ARN and URL.
If `modules/eks` doesn't already create one, add:

```hcl
# inside modules/eks/main.tf
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
```

and expose in `modules/eks/outputs.tf`:

```hcl
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  # strip the "https://" prefix — IAM policy conditions need it bare
  value = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "vpc_id" {
  value = var.vpc_id   # or wherever the vpc module's id flows through
}
```

## 3. Call the module from each environment

In `environments/region-a/main.tf`:

```hcl
module "lb_controller" {
  source = "../../modules/lb-controller"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.eks.vpc_id
  aws_region        = "us-east-1"

  depends_on = [module.eks]
}
```

Same in `environments/region-b/main.tf` with `aws_region = "eu-west-1"`.

## 4. Apply

Nothing else changes in your pipeline — `terraform apply` in the on-demand
workflow will now also stand up the controller before the sample app gets
deployed. First apply will take a few extra minutes while the Helm release
installs and the controller pod comes up.

## Keeping the policy current

`policy/aws-lb-controller-policy.json` is a snapshot of the official policy
from `kubernetes-sigs/aws-load-balancer-controller`. Re-fetch periodically:

```bash
curl -s https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json \
  -o modules/lb-controller/policy/aws-lb-controller-policy.json
```
