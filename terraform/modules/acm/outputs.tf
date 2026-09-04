output "certificate_arn" {
  description = "ARN of the provisioned AWS ACM certificate"
  value       = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].arn : ""
}

output "certificate_status" {
  description = "Status of the AWS ACM certificate"
  value       = length(aws_acm_certificate.cert) > 0 ? aws_acm_certificate.cert[0].status : "DISABLED"
}
