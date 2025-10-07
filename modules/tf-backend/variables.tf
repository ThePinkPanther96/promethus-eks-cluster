terraform {
  required_version = ">= 1.5.0"
}

variable "state_bucket" {
  description = "Globally-unique S3 bucket name for Terraform state"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}