module "eks_subnets" {
  source = "./modules/eks-subnets"

  vpc_id = "vpc-01726edb057271e76"

  azs = ["eu-central-1a", "eu-central-1b"]

  public_subnet_cidrs  = ["10.0.20.0/24",  "10.0.40.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.30.0/24"]

  cluster_name = "prometheus"
  name_prefix  = "prometheus"
  tags = {
    owner  = "gal"
    scope  = "observability"
    project= "prometheus"
  }
}