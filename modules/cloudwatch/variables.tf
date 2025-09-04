variable "vpc_id" {
  type = string
}

variable "owner" {
    type = string
}

variable "scaleInAdjustment" {
  type = number
}

variable "scaleOutAdjustment" {
  type = number
}

variable "highthreshold" {
  type = number
}

variable "lowthreshold" {
  type = number
}

variable "asg_name" {
  type = string
}
