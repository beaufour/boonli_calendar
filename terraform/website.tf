#
# Setup for website
#

#######################################
# Local variables
locals {
  domain_name     = "${var.subdomain_name}.${data.google_dns_managed_zone.dns_zone.dns_name}"
  api_domain_name = "api.${local.domain_name}"
}


#######################################
# Load balancer
resource "google_compute_global_address" "website" {
  name = "${var.project_name}-website-ip"
}

resource "google_compute_url_map" "website" {
  name            = "${var.project_name}-website-urlmap"
  default_service = google_compute_backend_bucket.website.id

  host_rule {
    hosts        = [trimsuffix(local.api_domain_name, ".")]
    path_matcher = "api"
  }

  path_matcher {
    name            = "api"
    default_service = google_compute_backend_service.api.id

    path_rule {
      paths   = ["/favicon.ico"]
      service = google_compute_backend_bucket.website.id
    }
  }
}

resource "google_compute_region_network_endpoint_group" "api" {
  name                  = "${var.project_name}-neg"
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    url_mask = "/<function>"
  }
  region = var.region
}

resource "google_compute_backend_service" "api" {
  name                  = "${var.project_name}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_backend_bucket" "website" {
  name        = "${var.project_name}-website-bucket"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true
}

resource "google_compute_global_forwarding_rule" "website" {
  name                  = "${var.project_name}-website-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.website.id
  ip_address            = google_compute_global_address.website.id
  port_range            = "443"
}

resource "google_compute_target_https_proxy" "website" {
  name             = "${var.project_name}-website-https-proxy"
  url_map          = google_compute_url_map.website.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}


#######################################
# Load balancer HTTP -> HTTPS
# Disabled as it costs...
# resource "google_compute_target_http_proxy" "website_http_redirect" {
#   name    = "${var.project_name}-website-https-redirect-proxy"
#   url_map = google_compute_url_map.website_http_redirect.id
# }

# resource "google_compute_url_map" "website_http_redirect" {
#   name = "${var.project_name}-website-https-redirect-url-map"
#   default_url_redirect {
#     https_redirect = true
#     strip_query    = false
#   }
# }

# resource "google_compute_global_forwarding_rule" "website_http_redirect" {
#   name                  = "${var.project_name}-website-http-forwarding-rule"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   ip_address            = google_compute_global_address.website.id
#   target                = google_compute_target_http_proxy.website_http_redirect.id
#   port_range            = "80"
# }


#######################################
# Bucket and files
resource "google_storage_bucket" "website" {
  name     = "${var.project_name}-website-bucket"
  location = "US"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_storage_bucket_iam_member" "website" {
  bucket = google_storage_bucket.website.id
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}


#######################################
# DNS
data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone
}

resource "google_dns_record_set" "website" {
  name = local.domain_name
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_global_address.website.address]
}

resource "google_dns_record_set" "api" {
  name = local.api_domain_name
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_global_address.website.address]
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.project_name}-certificate"
  managed {
    domains = [local.domain_name, local.api_domain_name]
  }
}
