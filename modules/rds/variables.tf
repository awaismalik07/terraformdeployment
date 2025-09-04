variable "vpc-cidr" {
    type = string
}

variable "vpc_id" {
  type = string
}

variable "owner" {
    type = string
}

variable "PrivateSubnets" {
  type = list(string)
}

variable "DBUsername" {
  type = string
}

variable "DBInstanceClass" {
  type = string
}

variable "DBName" {
    type = string
}

variable "DBAllocatedStorage" {
  type = number
  default = 20
}