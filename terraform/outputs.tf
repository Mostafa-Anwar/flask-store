output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for the Flask app"
  value       = aws_ecr_repository.flask_app.repository_url
}
