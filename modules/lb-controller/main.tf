# -----------------------------------------------------------------------------
# IRSA (IAM Role for Service Account) so the controller pod can call the AWS
# ELBv2 / EC2 APIs to create and manage ALBs on behalf of Ingress objects.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.cluster_name}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json
}

# Official policy from kubernetes-sigs/aws-load-balancer-controller, vendored
# in policy/aws-lb-controller-policy.json. Re-download and diff periodically
# from:
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.cluster_name}-aws-lb-controller-policy"
  policy = file("${path.module}/policy/aws-lb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# -----------------------------------------------------------------------------
# Kubernetes service account, annotated with the IRSA role so pods that mount
# it get temporary AWS credentials automatically (no static keys in-cluster).
# -----------------------------------------------------------------------------

resource "kubernetes_service_account" "lb_controller" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lb_controller]
}

# -----------------------------------------------------------------------------
# The controller itself, installed via the upstream Helm chart.
# -----------------------------------------------------------------------------

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = var.namespace

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  depends_on = [kubernetes_service_account.lb_controller]
}
