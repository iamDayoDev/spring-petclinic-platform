variable "aws_region" { default = "us-east-1" }
variable "cluster_name" { default = "petclinic-eks" }
variable "environment" { default = "production" }
variable "domain" { default = "eta-oko.com" }
variable "eso_role_name" { default = "petclinic-eso-role" }
variable "alb_role_name" { default = "petclinic-alb-role" }
variable "alb_policy_name" { default = "AWSLoadBalancerControllerIAMPolicy" }
