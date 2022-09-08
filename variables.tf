variable "resource_group_name" {
  default = "myTFResourceGroup"
}

##availabilty zones
variable "zone" {
  default=["1", "2"]
}

variable "server_zones" { 
  type = list
  default = [ "1", "2" ]
}