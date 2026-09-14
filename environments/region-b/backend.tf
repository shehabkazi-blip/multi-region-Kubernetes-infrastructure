terraform {
  backend "s3" {
    bucket         = "my-terraform-state-shehab-2026"
    key            = "multi-region-k8s-infrastructure/region-b/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
