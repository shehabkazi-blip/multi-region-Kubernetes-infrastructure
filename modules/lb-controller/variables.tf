variable "cluster_name" {
  description = "Name of the EKS cluster to install the controller into"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (from the eks module output)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster's IAM OIDC provider, without the https:// prefix (from the eks module output)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the EKS cluster runs in"
  type        = string
}

variable "aws_region" {
  description = "AWS region the cluster is deployed in"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install the controller into"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Kubernetes service account name used by the controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart"
  type        = string
  default     = "1.8.1"
}
