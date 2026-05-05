variable "vpc_id" {
  description = "ID of the VPC where the RDS instance is deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "eks_cidr" {
  description = "CIDR block allowed to reach MySQL (EKS node CIDR)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "petclinic"
}
