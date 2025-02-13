# Use Amazon S3 for Terraform backend
terraform {
  backend "s3" {}
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    subtype = "public"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  tags = {
    subtype = "private"
  }
}

locals {
  pvt_subnet_ids_string = join(",", data.aws_subnets.private.ids)
  pvt_subnet_ids_list = split(",", local.pvt_subnet_ids_string)
  pub_subnet_ids_string = join(",", data.aws_subnets.public.ids)
  pub_subnet_ids_list = split(",", local.pub_subnet_ids_string)
}