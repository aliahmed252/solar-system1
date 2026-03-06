resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
    }
  )

}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnets_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnets_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true # O

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}" #iti-private-1 and iti-private-1
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  count  = var.create_nat_per_az ? length(var.azs) : 1
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  count         = var.create_nat_per_az ? length(var.azs) : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.create_nat_per_az ? aws_subnet.public[count.index].id : aws_subnet.public[0].id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

}

resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route" "private_nat" {
  count                  = length(aws_route_table.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.create_nat_per_az ? aws_nat_gateway.this[count.index].id : aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}_eks-cluster-role"
  })
}


# Attach the managed policy for EKS Cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for ec2 instances
resource "aws_iam_role" "ec2_node_role" {
  name = "ec2_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}_ec2_node_role"
  })
}


# Attach the managed policy for ec2 role node
resource "aws_iam_role_policy_attachment" "ec2_node_worker_policy" {
  role       = aws_iam_role.ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_node_ecr_policy" {
  role       = aws_iam_role.ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_node_cni_policy" {
  role       = aws_iam_role.ec2_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


resource "aws_security_group" "eks_sg" {
  name        = "${var.name_prefix}_eks_sg"
  description = "security_group for EKS control plane "
  vpc_id      = aws_vpc.this.id
  ingress {
    description = "allow https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "the outcome traffic"
    from_port   = 0    # allow any port
    to_port     = 0    # allow any port
    protocol    = "-1" # allow all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, {
    Name = "${var.name_prefix}_eks-sg"
  })

}


resource "aws_security_group" "eks_node_sg" {
  name        = "${var.name_prefix}_eks_node_sg"
  description = "security_group for eks worker nodes"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "node to node communication"
    from_port   = 0
    to_port     = 0 #allow all ports form 0 to 65535
    protocol    = "-1"  # all protocols
    self        = true  #any resource (node,pods) has the same security group (eks_node_sg) can talk to others nodes
  }

  ingress {
    description = "allow kubelet communication"
    from_port   = 10250 # this is the kubelet port
    to_port     = 10250 #any ip can access the kubelet
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow http from cluster"
    from_port   = 443
    to_port     = 443
    # any resource has (cluster security group) can talk to the nodes on port 443
    protocol        = "tcp" #this import to make the control plane communicate with the nodes
    security_groups = [aws_security_group.eks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0 #allow all outcome traffic on any port on any protocol
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, {
    name = "${var.name_prefix}_eks_node_sg"
  })
}


resource "aws_eks_cluster" "eks" {
  name = "${var.name_prefix}_eks"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      for s in aws_subnet.public : s.id
    ]
    security_group_ids = [aws_security_group.eks_sg.id]
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_attach,
  ]
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.name_prefix}_node_group"
  node_role_arn   = aws_iam_role.ec2_node_role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1 # on update the max size of unavailable nodes =1
    #this means the update is node by node for (high availability)
  }
  ami_type  = "AL2_x86_64"
  disk_size = 10

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.ec2_node_worker_policy,
    aws_iam_role_policy_attachment.ec2_node_cni_policy,
    aws_iam_role_policy_attachment.ec2_node_ecr_policy
  ]
}

resource "null_resource" "generate_kubeconfig" {
  #empty resource use for trigger or provisioners
  depends_on = [aws_eks_cluster.eks]
  provisioner "local-exec" {
    #execute the following command on the local device
    command = "aws eks --region ${var.region} update-kubeconfig --name ${aws_eks_cluster.eks.name}"

  }
}
