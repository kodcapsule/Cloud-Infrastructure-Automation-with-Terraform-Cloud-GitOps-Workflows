output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.web-server.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web-server.public_ip
}