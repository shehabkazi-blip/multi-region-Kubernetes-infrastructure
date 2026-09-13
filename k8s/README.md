# k8s/ — Kustomize base + production overlays

```
k8s/
├── base/                          # shared, environment-agnostic manifests
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml                   # not wired into base/kustomization.yaml;
│                                   # opt-in per overlay (see below)
└── overlays/
    └── production/
        ├── region-a/               # patches base for the us-east-1 cluster
        │   ├── kustomization.yaml
        │   └── patch-region.yaml
        └── region-b/               # patches base for the eu-west-1 cluster
            ├── kustomization.yaml
            └── patch-region.yaml
```

## Why this shape

`base/` holds the manifests that are identical everywhere: object names, ports,
probes, security context. Each `overlays/production/<region>/kustomization.yaml`
then layers on what's different for that cluster:

- **image** — points at that region's ECR repository (`images:` transformer)
- **replica count** — production runs 3 pods, not the base's 2
- **region env var / resource sizing / pull policy** — via `patch-region.yaml`
- **HPA** — pulled in explicitly as an extra resource (production only; the
  base intentionally does NOT enable autoscaling so that a plain
  `kubectl apply -k base/` for a quick dev test stays predictable)
- **labels** — `environment: production`, `region: <aws-region>` via `commonLabels`

If you later add a `staging` overlay, copy the `production/` folder as a
template and adjust replica counts / resource sizing down.

## Before you deploy

Replace `<ACCOUNT_ID>` in both overlay `kustomization.yaml` files with your
real AWS account ID, or set it at apply time:

```bash
cd k8s/overlays/production/region-a
kustomize edit set image sample-app=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/sample-app:<TAG>
```

## Preview and apply

```bash
# Render the final manifests without applying (sanity check)
kubectl kustomize k8s/overlays/production/region-a
kubectl kustomize k8s/overlays/production/region-b

# Apply to each cluster
kubectl --context region-a apply -k k8s/overlays/production/region-a
kubectl --context region-b apply -k k8s/overlays/production/region-b
```

See `DEPLOY_INSTRUCTIONS.md` at the repo root for the full build → push →
deploy walkthrough (image build/push, kubeconfig setup, verification steps).
