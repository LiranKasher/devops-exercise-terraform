variable "account_id" {
  type        = string
  description = "AWS account ID"
}

variable "region" {
  type        = string
  default     = "il-central-1"
  description = "AWS region"
}

variable "cluster_name" {
  type        = string
  default     = "devops-exercise"
  description = "Name of the EKS cluster"
}

variable "vpc_name" {
  type        = string
  default     = "DevopsExerciseVpc"
  description = "Name of the VPC"
}

variable "role_name" {
  type        = string
  default     = "GitHubOIDCDeployRole"
  description = "IAM role name for GitHub OIDC"
}

variable "github_org" {
  type        = string
  description = "GitHub org/user for OIDC trust policy"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo name for OIDC trust policy"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type for EKS nodes"
}

variable "desired_capacity" {
  type        = number
  default     = 2
  description = "Desired number of nodes in the node group"
}

variable "min_size" {
  type        = number
  default     = 2
  description = "Minimum number of nodes in the node group"
}

variable "max_size" {
  type        = number
  default     = 4
  description = "Maximum number of nodes in the node group"
}
