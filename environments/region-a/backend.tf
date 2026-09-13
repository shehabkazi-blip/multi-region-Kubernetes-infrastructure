terraform {
  backend "s3" {
    # Replace with your actual state bucket / lock table before first init.
    bucket         = "my-terraform-state-shehab-2026"
    key            = "multi-region-k8s-infrastructure/region-a/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
