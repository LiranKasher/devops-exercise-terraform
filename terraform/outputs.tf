output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API server endpoint"
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  description = "EKS cluster certificate authority data"
  sensitive   = true
}

output "cluster_oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "OIDC provider ARN created by EKS"
}

output "github_deploy_role_arn" {
  value       = aws_iam_role.github_oidc_deploy.arn
  description = "IAM role ARN for GitHub Actions OIDC"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECR repository URL for the app"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs"
}

output "ebs_csi_driver_role_arn" {
  value       = module.ebs_csi_driver_irsa.iam_role_arn
  description = "EBS CSI driver IAM role ARN"
}

output "aws_load_balancer_controller_role_arn" {
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
  description = "AWS Load Balancer Controller IAM role ARN"
}

output "fluent_bit_role_arn" {
  value       = module.fluent_bit_irsa.iam_role_arn
  description = "Fluent Bit IAM role ARN"
}

output "aws_auth_roles" {
  value       = data.kubernetes_config_map.aws_auth.data["mapRoles"]
  description = "Current mapRoles section of the aws-auth ConfigMap"
}