resource "aws_codebuild_project" "terraform_apply" {
  name          = "hirata-automation-terraform-apply-project"
  description   = "Build project for applying Terraform changes from CodeCommit"
  build_timeout = "5"
  service_role = "arn:aws:iam::990209979466:role/service-role/codebuild-terraform-service-role"
  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type      = "CODECOMMIT"
    location  = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/hirata-automation-terraform-repo"
  }
}

data "aws_caller_identity" "current" {}

# S3: Bucket (Access Logs)
resource "aws_s3_bucket" "hirata_automation_codepipline_artifact" {
  bucket = "hirata-automation-artifact-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = "hirata_automation_artifact_${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hirata_automatio_codepipline_artifact_sse" {
  bucket = aws_s3_bucket.hirata_automation_codepipline_artifact.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "hirata_automation_codepipline_artifact_policy" {
  bucket = aws_s3_bucket.hirata_automation_codepipline_artifact.id
  policy = data.aws_iam_policy_document.hirata_automation__codepipline_artifact_policy_document.json
}

data "aws_iam_policy_document" "hirata_automation__codepipline_artifact_policy_document" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.hirata_automation_codepipline_artifact.arn}/*",
      aws_s3_bucket.hirata_automation_codepipline_artifact.arn
    ]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}


resource "aws_codepipeline" "terraform_pipeline" {
  name     = "hirata-automation-terraform-pipeline"
  role_arn = "arn:aws:iam::990209979466:role/service-role/AWSCodePipelineServiceRole-us-east-1-terraform"
  artifact_store {
    type     = "S3"
    location = "hirata-automation-artifact-${data.aws_caller_identity.current.account_id}"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = "hirata-automation-terraform-repo"
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration    = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }
}
