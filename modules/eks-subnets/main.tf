locals {
  public_map  = { for i, az in var.azs : az => var.public_subnet_cidrs[i] }
  private_map = { for i, az in var.azs : az => var.private_subnet_cidrs[i] }

  base_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "Project"                                   = "eks"
    },
    var.tags
  )
}

resource "aws_subnet" "public" {
  for_each                = local.public_map
  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(
    local.base_tags,
    {
      "Name"                     = "${var.name_prefix}-public-${each.key}"
      "kubernetes.io/role/elb"   = "1"
      "Tier"                     = "public"
    }
  )
}

resource "aws_subnet" "private" {
  for_each                = local.private_map
  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge(
    local.base_tags,
    {
      "Name"                              = "${var.name_prefix}-private-${each.key}"
      "kubernetes.io/role/internal-elb"   = "1"
      "Tier"                              = "private"
    }
  )
}