variable "vpc_id" {
  type = string
}
variable "owner" {
    type = string
}

variable "imageid" {
  type = string
}

variable "ec2instancetype" {
  type = string
}

variable "keypairname" {
  type = string
}

variable "db_secretmanager_name" {
  type = string
}

variable "PrivateSubnets" {
  type = list(string)
}

variable "PublicSubnets" {
  type = list(string)
}

variable "desiredcapacity" {
  type = number
}

variable "minsize" {
  type = number
}

variable "maxsize" {
  type = number
}

variable "acmcert" {
  type = string
}