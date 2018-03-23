variable "region" {}

variable "servers_per_az" {
  default = 1
}

variable "instance_type" {
  default = "t2.micro"
}

variable "r53_zone_id" {
  default = "Z3CN2CVJS242T6"
}

variable "r53_domain_name" {
  default = "cdn"
}

# Ubuntu Server 16.04 LTS (HVM), SSD Volume Type (64)
variable "amis" {
  type = "map"

  default = {
    "sydney" = "ami-33ab5251" #Sydney
    "tokyo"  = "ami-48630c2e" #Tokyo

    "n-virginia" = "ami-66506c1c" #North Virginia
    "oregon"     = "ami-79873901" #Oregon
  }
}

variable "evaluate_target_health" {
  default = "false"
}
