variable "name" {
  description = "Name prefix for all VPC resources (e.g. \"region-a\")"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (2-3 recommended)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ, same order as var.azs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (where EKS nodes run), one per AZ, same order as var.azs"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "If true, create one NAT gateway shared by all private subnets (cheaper). If false, one NAT gateway per AZ (more resilient, costs more)."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name that will run in this VPC — used for the kubernetes.io/cluster/<name> tag required by the AWS Load Balancer Controller and cluster autoscaler"
  type        = string
}

variable "tags" {
  description = "Extra tags applied to all resources"
  type        = map(string)
  default     = {}
}
