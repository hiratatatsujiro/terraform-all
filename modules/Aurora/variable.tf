variable "vpc_id" {
  type = string
}

variable "engine" {
  type = string
}

variable "parameter_group_family" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}