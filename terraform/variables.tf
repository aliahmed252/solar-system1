variable "region" {
  description = "name of the region"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "name_prefix" {
  description = "name of the project"
  type        = string
  default     = "final-project"
}

variable "vpc_cidr" {
  description = "cidrs block"
  type        = string
  default     = "10.42.0.0/16"
}

variable "tags" {
  description = "additional tags"
  type        = map(string)
  default     = {}
}

variable "public_subnet_cidrs" {
  description = "public_subnet_cidrs"
  type        = list(string)
  default     = ["10.42.1.0/24", "10.42.2.0/24"]
}

variable "private_subnets_cidrs" {
  description = "private_subnets_cidrs"
  type        = list(string)
  default     = ["10.42.11.0/24", "10.42.12.0/24"]

}

variable "create_nat_per_az" {
  description = "create_nat_per_az"
  type        = bool
  default     = false

}

variable "desired_size" {
  description = "the desired_size of ec2"
  type        = number
  default     = 2

}

variable "min_size" {
  description = "the min_size of ec2"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "the max_size of ec2"
  type        = number
  default     = 3
}