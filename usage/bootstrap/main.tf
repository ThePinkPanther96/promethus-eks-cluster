module "tf_backend" {
  source       = "../modules/tf-backend"
  state_bucket = "backend-tf-state-021891580761-eu-central-1-eks-deployment"
  lock_table   = "terraform-locks"
  tags = { 
    owner  = "gal"
    scope  = "observability"
    project= "prometheus"
  }
}