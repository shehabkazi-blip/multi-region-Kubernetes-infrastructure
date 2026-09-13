output "iam_role_arn" {
  description = "ARN of the IRSA role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "service_account_name" {
  description = "Kubernetes service account name used by the controller"
  value       = kubernetes_service_account.lb_controller.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.lb_controller.status
}
