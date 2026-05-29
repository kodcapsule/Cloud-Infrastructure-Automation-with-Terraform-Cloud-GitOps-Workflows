terraform {
  cloud {
    organization = "your-org-name"

    workspaces {
      name = "aws-ec2-prod"
    }
  }
}