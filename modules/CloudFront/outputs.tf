output "s3_bucket_static_contents_arn" {
  value = aws_s3_bucket.hirata_automation_static_contents.arn
}

output "secret_string" {
  value = aws_secretsmanager_secret_version.cloudfront_secret_version.secret_string
}