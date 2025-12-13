resource "aws_ecr_repository" "app" {
  name                 = "devops-exercise"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = {
    Project = "devops-exercise"
  }
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  repository = aws_ecr_repository.app.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 30 days"
      selection    = {
        tagStatus     = "untagged"
        countType     = "sinceImagePushed"
        countUnit     = "days"
        countNumber   = 30
      }
      action       = { type = "expire" }
    }]
  })
}