#######################################
# Local variables
locals {
  domain_name     = "${var.subdomain_name}.${data.google_dns_managed_zone.dns_zone.dns_name}"
  api_domain_name = "api.${local.domain_name}"
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.project_name}-certificate"
  managed {
    domains = [local.domain_name, local.api_domain_name]
  }
}

data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone
}
