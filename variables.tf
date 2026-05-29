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



# variable "ami_id" {
#   description = "Id for AMI"
#   type        = string
# }