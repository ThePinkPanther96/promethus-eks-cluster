variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "azs" {
  description = "AZs to place subnets in (order matters vs CIDRs)"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (same length as azs)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (same length as azs)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name for tagging"
  type        = string
  default     = "prometheus"
}

variable "name_prefix" {
  description = "Name tag prefix"
  type        = string
  default     = "prometheus"
}

variable "tags" {
  description = "Extra tags to merge"
  type        = map(string)
  default     = {}
}