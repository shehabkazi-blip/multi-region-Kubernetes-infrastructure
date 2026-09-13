# Documentation

## modules/vpc

Creates one VPC per region with public subnets (for NAT gateways / ALBs) and
private subnets (for EKS worker nodes), spread across the AZs you pass in.

- `single_nat_gateway = true` (default) — one shared NAT gateway, cheaper,
  single point of failure for outbound traffic from private subnets. Set to
  `false` for one NAT gateway per AZ if that trade-off matters for your
  workload.
- Subnets are tagged `kubernetes.io/cluster/<name> = shared` and
  `kubernetes.io/role/elb` / `internal-elb` — required for the AWS Load
  Balancer Controller to auto-discover which subnets to place ALBs/NLBs in.

## modules/eks

- Control plane + IAM role with `AmazonEKSClusterPolicy`.
- One managed node group in **private subnets only** — worker nodes are never
  directly internet-reachable.
- `lifecycle { ignore_changes = [scaling_config[0].desired_size] }` on the
  node group — once a cluster autoscaler or Karpenter is managing the node
  count, Terraform won't fight it over `desired_size`.
- OIDC provider (`aws_iam_openid_connect_provider`) is created here — this is
  what makes IRSA (IAM Roles for Service Accounts) possible, and is what
  `modules/lb-controller` depends on.
- Core addons (`vpc-cni`, `kube-proxy`, `coredns`) are installed as
  AWS-managed EKS addons rather than left to whatever the AMI ships, so they
  get patched via `terraform apply` instead of drifting silently.

## modules/lb-controller

See `modules/lb-controller/WIRING.md` for the full explanation — in short,
this installs the AWS Load Balancer Controller via Helm with an IRSA role,
which is what turns a Kubernetes `Ingress` object into an actual ALB.

## environments/region-a, environments/region-b

Each environment:
1. Configures the `aws` provider for its region.
2. Calls `modules/vpc` and `modules/eks`.
3. Uses `aws_eks_cluster_auth` to fetch a short-lived token, then configures
   the `kubernetes` and `helm` providers against the cluster it just created
   — this lets Terraform install the load balancer controller in the same
   `apply` that creates the cluster, no separate manual step needed.
4. Calls `modules/lb-controller`.

They're deliberately **not** a single shared module with a `region` variable
— region-a and region-b have separate state files (`backend.tf`), so a bad
apply in one region can never touch the other's state. If the two ever drift
apart in ways that matter (different instance types, different node counts),
that's supported by design, not a workaround.

## Why two Terraform state files instead of one with workspaces

Terraform workspaces share a single backend config and are easy to apply to
the wrong workspace by accident. Separate directories with separate
`backend.tf` files make the blast radius of any single `terraform apply`
obvious from the path you're standing in.

## Known simplifications / things to revisit before real production traffic

- Single managed node group per cluster — no Spot/On-Demand mix, no
  Karpenter. Fine for a test/demo workload; revisit if you need
  cost-optimized or GPU node pools.
- No cross-region Route 53 failover/latency routing wired up yet — the ALBs
  in each region are independent. Add that once you have real DNS record
  requirements.
- `endpoint_public_access = true` on the EKS API server by default — fine for
  getting started, but consider restricting to a VPN/bastion CIDR
  (`endpoint_public_access_cidrs`) before this holds real workloads.
