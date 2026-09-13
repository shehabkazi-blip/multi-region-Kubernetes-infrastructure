# Deploying the Sample App to Region A and Region B EKS Clusters

This assumes:
- You have an ECR repository `sample-app` created in each region (or one central repo replicated via ECR cross-region replication).
- `aws-cli`, `docker`, `kubectl`, and `helm` are installed and configured.
- Your kubeconfig can reach both clusters (via `aws eks update-kubeconfig`).
- The AWS Load Balancer Controller is installed on both EKS clusters (required for the `ingress.yaml` / Helm ingress to provision an ALB).

Suggested repo placement (matches your existing structure):

```
multi-region-k8s-infrastructure/
├── app/                     # from this package
├── k8s/                     # raw manifests (alternative to Helm)
├── helm/sample-app/         # Helm chart (recommended)
├── modules/
├── environments/
└── ...
```

## 1. Build and push the Docker image (per region)

ECR is regional, so push the same image to both regions' registries.

```bash
export ACCOUNT_ID=<your-aws-account-id>
export TAG=$(git rev-parse --short HEAD)   # or "latest", or a semver tag

# Region A
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

aws ecr describe-repositories --repository-names sample-app --region us-east-1 || \
  aws ecr create-repository --repository-name sample-app --region us-east-1

docker build -t ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/sample-app:${TAG} ./app
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/sample-app:${TAG}

# Region B
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com

aws ecr describe-repositories --repository-names sample-app --region eu-west-1 || \
  aws ecr create-repository --repository-name sample-app --region eu-west-1

docker build -t ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/sample-app:${TAG} ./app
docker push ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/sample-app:${TAG}
```

Tip: build once and re-tag/push to both regions instead of building twice, since the image contents are identical:
```bash
docker build -t sample-app:${TAG} ./app
docker tag sample-app:${TAG} ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/sample-app:${TAG}
docker tag sample-app:${TAG} ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/sample-app:${TAG}
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/sample-app:${TAG}
docker push ${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/sample-app:${TAG}
```

## 2. Point kubectl at each cluster

```bash
aws eks update-kubeconfig --name <region-a-cluster-name> --region us-east-1 --alias region-a
aws eks update-kubeconfig --name <region-b-cluster-name> --region eu-west-1 --alias region-b
```

## 3a. Option A — Deploy with Helm (recommended)

```bash
# Region A
helm upgrade --install sample-app ./helm/sample-app \
  --kube-context region-a \
  --namespace sample-app --create-namespace \
  -f ./helm/sample-app/values-region-a.yaml \
  --set image.tag=${TAG}

# Region B
helm upgrade --install sample-app ./helm/sample-app \
  --kube-context region-b \
  --namespace sample-app --create-namespace \
  -f ./helm/sample-app/values-region-b.yaml \
  --set image.tag=${TAG}
```

Update `values-region-a.yaml` / `values-region-b.yaml` with your actual account ID and cluster-specific overrides (node selectors, replica counts, etc.) before running.

## 3b. Option B — Deploy with raw manifests (kubectl)

Replace the placeholders in `k8s/deployment.yaml` (`<ACCOUNT_ID>`, `<REGION>`, `<TAG>`, `REGION_PLACEHOLDER`) per region, or use `envsubst` / `kustomize` overlays. Example with `sed` for a quick one-off deploy:

```bash
# Region A
sed -e "s#<ACCOUNT_ID>#${ACCOUNT_ID}#g" \
    -e "s#<REGION>#us-east-1#g" \
    -e "s#<TAG>#${TAG}#g" \
    -e "s#REGION_PLACEHOLDER#us-east-1#g" \
    k8s/deployment.yaml | kubectl --context region-a apply -f -

kubectl --context region-a apply -f k8s/namespace.yaml
kubectl --context region-a apply -f k8s/service.yaml
kubectl --context region-a apply -f k8s/ingress.yaml

# Region B (repeat with eu-west-1 values)
sed -e "s#<ACCOUNT_ID>#${ACCOUNT_ID}#g" \
    -e "s#<REGION>#eu-west-1#g" \
    -e "s#<TAG>#${TAG}#g" \
    -e "s#REGION_PLACEHOLDER#eu-west-1#g" \
    k8s/deployment.yaml | kubectl --context region-b apply -f -

kubectl --context region-b apply -f k8s/namespace.yaml
kubectl --context region-b apply -f k8s/service.yaml
kubectl --context region-b apply -f k8s/ingress.yaml
```

For anything beyond a quick test, prefer the Helm option — it avoids hand-editing manifests and keeps region differences isolated to the `values-region-*.yaml` files.

## 3c. Option C — Deploy with Kustomize (base + production overlays)

`k8s/base/` holds the shared manifests; `k8s/overlays/production/region-a` and
`region-b` layer on the production image, replica count, resource sizing, and
an HPA for each cluster. See `k8s/README.md` for the full breakdown.

```bash
# Set the real image once per overlay (or edit the kustomization.yaml directly)
(cd k8s/overlays/production/region-a && kustomize edit set image \
  sample-app=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/sample-app:${TAG})
(cd k8s/overlays/production/region-b && kustomize edit set image \
  sample-app=${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com/sample-app:${TAG})

# Sanity-check the rendered output
kubectl kustomize k8s/overlays/production/region-a
kubectl kustomize k8s/overlays/production/region-b

# Apply
kubectl --context region-a apply -k k8s/overlays/production/region-a
kubectl --context region-b apply -k k8s/overlays/production/region-b
```

## 4. Verify the deployment

```bash
kubectl --context region-a -n sample-app get pods,svc,ingress
kubectl --context region-b -n sample-app get pods,svc,ingress

# Once the ALB is provisioned (takes 1-3 min), get its address:
kubectl --context region-a -n sample-app get ingress sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

curl http://<alb-hostname-region-a>/
curl http://<alb-hostname-region-b>/
```

Each response includes the `region` field so you can confirm which cluster served the request — useful for validating routing/failover (e.g. via Route 53 latency-based or failover records pointing at each region's ALB).

## 5. Wiring into CI (optional next step)

Your existing `.github/workflows/terraform-ci.yml` handles infrastructure. Consider adding a separate `app-ci.yml` workflow that:
1. Builds and pushes the image to both ECR repos on merge to `main`.
2. Runs `helm upgrade --install` against both clusters using OIDC-federated AWS credentials (no long-lived keys).
3. Runs a smoke test (`curl` the `/healthz` endpoint) against both regions before marking the deploy successful.

Happy to draft that workflow file if you'd like it added next.
