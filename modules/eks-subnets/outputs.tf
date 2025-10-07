output "public_subnet_ids" {
  description = "List of public subnet IDs (sorted by AZ)"
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (sorted by AZ)"
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "public_subnets_by_az" {
  description = "Map AZ => public subnet ID"
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnets_by_az" {
  description = "Map AZ => private subnet ID"
  value       = { for az, s in aws_subnet.private : az => s.id }
}