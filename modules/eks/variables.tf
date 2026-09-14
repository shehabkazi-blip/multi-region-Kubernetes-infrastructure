variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID the cluster runs in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane ENIs and worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — included in cluster subnet list so public-facing ALBs can be provisioned by the AWS Load Balancer Controller"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is reachable from the public internet"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "additional_admin_role_arn" {
  description = "IAM role ARN (e.g. the CI/CD role running Terraform) to explicitly grant EKS cluster-admin access via an Access Entry. Leave empty to skip."
  type        = string
  default     = ""
}


