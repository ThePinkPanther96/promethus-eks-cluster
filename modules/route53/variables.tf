variable "zone_name"   { type = string }            # e.g., "example.com"
variable "record_name" { type = string }            # e.g., "prometheus"
variable "alias_name"  { type = string }            # ALB DNS, e.g., "k8s-...elb.amazonaws.com"
variable "alias_zone_id" { type = string }          # ALB hosted zone ID (from aws_lb.zone_id)