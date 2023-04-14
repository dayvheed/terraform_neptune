## ------ Outputs --------------------------------------------------------------

output "neptune_endpoint" {
  value = aws_neptune_cluster_instance.example[0].endpoint
}

output "neptune_port" {
  value = aws_neptune_cluster_instance.example[0].port
}

output "ec2_instance_dns" {
  value = aws_instance.neptune-ec2-connector.public_dns
}

output "ec2_public_ip" {
  value = aws_instance.neptune-ec2-connector.public_ip
}

output "role_arn" {
  value = [aws_iam_role.neptune_loader_role.arn]
}