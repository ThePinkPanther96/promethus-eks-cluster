terraform {
  backend "s3" {
    bucket         = "backend-tf-state-021891580761-eu-central-1-eks-deployment"   # same as above
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
  }
}