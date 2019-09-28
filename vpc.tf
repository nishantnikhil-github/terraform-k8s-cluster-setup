#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "eks-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = "${
    map(
      "Name", "nishant-terraform-eks-node",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_subnet" "eks-vpc-subnet" {
  count = 2

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.eks-vpc.id}"

  tags = "${
    map(
      "Name", "nishant-terraform-eks-node",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "eks-vpc-ig" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  tags = {
    Name = "nishant-terraform-eks-ig"
  }
}

resource "aws_route_table" "eks-vpc-route_table" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.eks-vpc-ig.id}"
  }
}

resource "aws_route_table_association" "eks-vpc-route_table_association" {
  count = 2

  subnet_id      = "${aws_subnet.eks-vpc-subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.eks-vpc-route_table.id}"
}
