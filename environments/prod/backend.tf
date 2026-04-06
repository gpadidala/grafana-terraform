terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "grafana/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
