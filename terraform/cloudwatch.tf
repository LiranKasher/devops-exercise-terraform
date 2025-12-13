resource "aws_cloudwatch_log_group" "eks_application" {
  name              = "/eks/${var.cluster_name}/application"
  retention_in_days = 7

  tags = {
    Project = "devops-exercise"
  }
}