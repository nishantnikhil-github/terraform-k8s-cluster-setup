#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EC2 Security Group to allow networking traffic
#  * Data source to fetch latest EKS worker AMI
#  * AutoScaling Launch Configuration to configure worker instances
#  * AutoScaling Group to launch worker instances
#

resource "aws_iam_role" "nishant-terraform-eks-node" {
  name = "nishant-terraform-eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "nishant-terraform-eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.nishant-terraform-eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "nishant-terraform-eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.nishant-terraform-eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "nishant-terraform-eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.nishant-terraform-eks-node.name}"
}

resource "aws_iam_instance_profile" "nishant-terraform-eks-node" {
  name = "nishant-terraform-eks-node"
  role = "${aws_iam_role.nishant-terraform-eks-node.name}"
}

resource "aws_security_group" "nishant-terraform-eks-node-sg" {
  name        = "nishant-terraform-eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.eks-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "nishant-terraform-eks-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "nishant-terraform-eks-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.nishant-terraform-eks-node-sg.id}"
  source_security_group_id = "${aws_security_group.nishant-terraform-eks-node-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "nishant-terraform-eks-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.nishant-terraform-eks-node-sg.id}"
  source_security_group_id = "${aws_security_group.nishant-terraform-eks-cluster-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.nishant-terraform-eks-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  nishant-terraform-eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.nishant-terraform-eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.nishant-terraform-eks-cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "nishant-terraform-eks-lauch-config" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.nishant-terraform-eks-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "m4.large"
  name_prefix                 = "nishant-terraform-eks-node"
  security_groups             = ["${aws_security_group.nishant-terraform-eks-node-sg.id}"]
  user_data_base64            = "${base64encode(local.nishant-terraform-eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nishant-terraform-eks-asg" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.nishant-terraform-eks-lauch-config.id}"
  max_size             = 2
  min_size             = 1
  name                 = "nishant-terraform-eks-node"
  vpc_zone_identifier  = "${aws_subnet.eks-vpc-subnet[*].id}"

  tag {
    key                 = "Name"
    value               = "nishant-terraform-eks-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
