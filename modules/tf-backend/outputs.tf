output "bucket" {
  description = "State bucket name"
  value       = aws_s3_bucket.state.bucket
}
