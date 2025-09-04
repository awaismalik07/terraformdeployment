variable "environment" {
  type = object({
    region = string
    owner  = string
  })
}

variable "vpc" {
  type = object({
    cidr = string
  })
}

variable "database" {
  type = object({
    username          = string
    name              = string
    instance_class    = string
    allocated_storage = number
  })
}

variable "compute" {
  type = object({
    image_id        = string
    instance_type   = string
    keypair_name    = string
    desired_capacity = number
    min_size        = number
    max_size        = number
  })
}

variable "scaling" {
  type = object({
    scale_in_adjustment  = number
    scale_out_adjustment = number
    high_threshold       = number
    low_threshold        = number
  })
}