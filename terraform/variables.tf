# The name of the Google Cloud Project to host the infrastructure in
variable "google_project_name" {
  type    = string
  default = "boonli-menu"
}

# The region to host the infrastructure in
variable "region" {
  type    = string
  default = "us-east1"
}

# Name of the project, which is used to name resources in Google Cloud
variable "project_name" {
  type    = string
  default = "boonli-menu"
}

# The Cloud DNS zone name to create entries in
variable "dns_zone" {
  type    = string
  default = "vovhund-com"
}

# The subdomain to create in the above DNS zone to host the app in
variable "subdomain_name" {
  type    = string
  default = "boonli"
}
