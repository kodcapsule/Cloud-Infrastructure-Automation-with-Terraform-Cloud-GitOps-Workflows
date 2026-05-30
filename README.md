# 🚀 Deploying AWS EC2 via Terraform Cloud

This is a  step-by-step guide for provisioning AWS resources using **Terraform Cloud**. This tutorial covers organizations and  workspace setup, credential management, and automated deployments via version control.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [1. Set Up Terraform Cloud](#1-set-up-terraform-cloud)
  - [2. Configure AWS Credentials](#2-configure-aws-credentials)
  - [3. Write Terraform Configuration](#3-write-terraform-configuration)
  - [4. Authenticate the Terraform CLI](#4-authenticate-the-terraform-cli)
  - [5. Initialize & Push to VCS](#5-initialize--push-to-vcs)
  - [6. Plan & Apply](#6-plan--apply)
- [Configuration Reference](#configuration-reference)
- [Outputs](#outputs)
- [Destroying Resources](#destroying-resources)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This tutorial walks you through deploying an **AWS EC2 instance** using [Terraform Cloud](https://app.terraform.io) as the remote state backend and CI/CD execution environment. Instead of running `terraform apply` locally, Terraform Cloud handles plan and apply runs automatically when you push code to your connected Git repository.

**What you'll learn:**
- Creating and configuring a Terraform Cloud workspace
- Storing AWS credentials securely as environment variables
- Writing modular Terraform configuration for EC2
- Triggering remote plan/apply runs via VCS integration
- Reading outputs (instance ID, public IP) from Terraform Cloud

---

## Prerequisites

Before you begin, ensure you have the following:

| Requirement | Details |
|---|---|
| **AWS Account** | With an IAM user that has EC2 permissions |
| **AWS IAM Credentials** | `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` |
| **Terraform Cloud Account** | Free at [app.terraform.io](https://app.terraform.io) |
| **Terraform CLI** | v1.5+ — [Install Guide](https://developer.hashicorp.com/terraform/install) |
| **Git** | Connected to GitHub, GitLab, or Bitbucket |

---

## Project Structure

```
.
├── main.tf           
├── variables.tf    
├── backend.tf  
├── provider.tf        
├── outputs.tf        
├── terraform.tfvars  
└── README.md
```

---

## Getting Started

### 1. Set Up Terraform Cloud

1. Log in to [app.terraform.io](https://app.terraform.io) and create an **Organization** (if you don't have one).
2. Click **New Workspace** → select **Version Control Workflow**.
3. Connect your VCS provider (GitHub, GitLab, or Bitbucket) and choose this repository.
4. Name your workspace (e.g., `aws-ec2-prod`) and click **Create workspace**.

---


### 2. Configure Dynamic AWS Credentials (OIDC)

Instead of storing long-lived AWS access keys, this tutorial uses **Terraform Cloud Dynamic Provider Credentials** — short-lived tokens issued via OpenID Connect (OIDC). This is the recommended, more secure approach.

#### Step A — Create an AWS IAM OIDC Identity Provider

In the **AWS Console → IAM → Identity Providers**, create a new OIDC provider:

| Field | Value |
|---|---|
| **Provider URL** | `https://app.terraform.io` |
| **Audience** | `aws.workload.identity` |

#### Step B — Create an IAM Role for Terraform Cloud

Create a new IAM role with the following **Trust Policy**, replacing the placeholders with your values:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:oidc-provider/app.terraform.io"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "app.terraform.io:aud": "aws.workload.identity"
        },
        "StringLike": {
          "app.terraform.io:sub": "organization:<YOUR_TFC_ORG>:project:*:workspace:<YOUR_WORKSPACE_NAME>:run_phase:*"
        }
      }
    }
  ]
}
```

Attach the **`AmazonEC2FullAccess`** policy (or a least-privilege custom policy) to this role and note the **Role ARN**.

#### Step C — Add Variables to Terraform Cloud

In your workspace, go to **Settings → Variables** and add the following as **Environment Variables**:

| Variable | Value | Sensitive |
|---|---|---|
| `TFC_AWS_PROVIDER_AUTH` | `true` | No |
| `TFC_AWS_RUN_ROLE_ARN` | `arn:aws:iam::<account-id>:role/<role-name>` | No |
| ` TFC_AWS_WORKLOAD_IDENTITY_AUDIENCE ` | `aws.workload.identity` | No |

> ✅ **No static keys required.** Terraform Cloud will automatically assume the IAM role using short-lived OIDC tokens for every run !.


---

### 3. Write Terraform Configuration

**`main.tf`**
```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}


resource "aws_instance" "web-server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  tags = {
    Name = "Terraform-Lab-Instance-${var.environment}"
  }
}


```

**`backend.tf`**
```hcl
terraform {
  cloud {
    organization = "your-org-name"

    workspaces {
      name = "aws-ec2-prod"
    }
  }
}
```
**`provider.tf`**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
}

provider "aws" {
  region = var.aws_region
}
```

**`variables.tf`**
```hcl
variable "instance_type" {
    description = "The type of instance to create"
    type        = string
    default     = "t2.micro"
  
}

variable "environment" {
  type = string
  default = "dev"
  description = "The environment for the instance"
}


variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}



variable "ami_id" {
  description = "Id for AMI"
  type        = string
}
```

**`outputs.tf`**
```hcl
output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}
```

---

### 4. Authenticate the Terraform CLI

Run the following to link your local CLI to Terraform Cloud:

```bash
terraform login
```

A browser window will open. Generate an API token and paste it into your terminal when prompted.

---

### 5. Initialize & Push to VCS

Initialize Terraform locally to link the workspace:

```bash
terraform init
```

Commit and push your configuration files:

```bash
git add main.tf variables.tf outputs.tf
git commit -m "feat: add EC2 terraform configuration"
git push origin main
```

> Pushing to the connected branch automatically triggers a **plan** run in Terraform Cloud.

---

### 6. Plan & Apply

1. Open your workspace in [Terraform Cloud](https://app.terraform.io).
2. Navigate to the **Runs** tab — you should see a new run triggered by your push.
3. Review the plan output to confirm the EC2 instance will be created.
4. Click **Confirm & Apply** to provision the instance.

After the apply completes, the **Outputs** section will show:
- `instance_id` — the AWS instance ID
- `public_ip` — the public IP address of your EC2 instance

Verify in the **AWS Console → EC2 → Instances**.

---

## Configuration Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `us-east-1` | AWS region to deploy into |
| `ami_id` | `string` | Amazon Linux 2 AMI | AMI ID (must match region) |
| `instance_type` | `string` | `t2.micro` | EC2 instance type |

> **Note:** AMI IDs are region-specific. Find the correct AMI for your region in the [AWS AMI Catalog](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html).

---

## Outputs

| Output | Description |
|---|---|
| `instance_id` | AWS-assigned ID of the EC2 instance (e.g., `i-0abcd1234ef567890`) |
| `public_ip` | Public IPv4 address assigned to the instance |

---

## Destroying Resources

To avoid ongoing AWS charges, destroy the resources when you're done:

1. In Terraform Cloud, go to your workspace → **Settings → Destruction and Deletion**.
2. Click **Queue destroy plan**.
3. Review and confirm the destroy run.

Alternatively, from the CLI:

```bash
terraform destroy
```

---

## Troubleshooting

**`Error: No valid credential sources found`**
→ Ensure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set as **Environment Variables** (not Terraform Variables) in your Terraform Cloud workspace.

**`InvalidAMIID.NotFound`**
→ The `ami_id` default is for `us-east-1`. Update `ami_id` in `variables.tf` to match your target region.

**`terraform init` fails with workspace not found**
→ Double-check the `organization` and `workspaces.name` values in the `cloud {}` block in `main.tf`.

**Run not triggered after `git push`**
→ Confirm the VCS connection in **Workspace Settings → Version Control** and ensure you're pushing to the correct branch.

---

## Contributing

Contributions are welcome! To contribute:

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Commit your changes: `git commit -m 'feat: add my improvement'`
4. Push to the branch: `git push origin feature/my-improvement`
5. Open a Pull Request

Please keep examples beginner-friendly and tested.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

> **Found this helpful?** Give the repo a ⭐ and share it with others learning Terraform!
