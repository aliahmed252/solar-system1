
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks.name
}


output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.eks.arn
}


output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks.endpoint
}


output "eks_security_group_id" {
  description = "Security group ID for the EKS control plane"
  value       = aws_security_group.eks_sg.id
}


output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}


output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "eks_node_group_name" {
  description = "Name of the EKS worker node group"
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

output "eks_node_role_arn" {
  description = "IAM Role ARN for EKS worker nodes"
  value       = aws_iam_role.ec2_node_role.arn
}

output "eks_cluster_certificate_authority_data" {
  description = "Certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}