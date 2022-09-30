#
# Setup for the API endpoints
#
# Note: here's also a 2nd gen Cloud Functions, but I've only had trouble with
# it. Either because it's fairly new or because Terraform doesn't handle it
# well. Or both...
#


#######################################
# Load Balancer
resource "google_compute_global_address" "default" {
  name = "${var.project_name}-ip"
}

resource "google_compute_region_network_endpoint_group" "default" {
  name                  = "${var.project_name}-neg"
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    url_mask = "/<function>"
  }
  region = var.region
}

resource "google_compute_backend_service" "default" {
  name                  = "${var.project_name}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  backend {
    group = google_compute_region_network_endpoint_group.default.id
  }
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-urlmap"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = "${var.project_name}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "${var.project_name}-https-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.default.id
  target                = google_compute_target_https_proxy.default.id
  port_range            = "443"
}


#######################################
# Load balancer HTTP -> HTTPS
resource "google_compute_target_http_proxy" "http_redirect" {
  name    = "${var.project_name}-https-redirect-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_url_map" "http_redirect" {
  name = "${var.project_name}-https-redirect-url-map"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_global_forwarding_rule" "http_redirect" {
  name                  = "${var.project_name}-http-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.default.id
  target                = google_compute_target_http_proxy.http_redirect.id
  port_range            = "80"
}


#######################################
# DNS
resource "google_dns_record_set" "default" {
  name = local.api_domain_name
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_global_address.default.address]
}


#######################################
# KMS
resource "google_kms_key_ring" "default" {
  name     = "${var.project_name}-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "default" {
  name     = "${var.project_name}-key"
  key_ring = google_kms_key_ring.default.id

  lifecycle {
    prevent_destroy = true
  }
}


#######################################
# Service account
resource "google_service_account" "default" {
  account_id   = "${var.project_name}-service-account"
  display_name = "Cloud Function Service Account"
}

# Gives the function access to the encryption/decryption key
resource "google_kms_crypto_key_iam_member" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.default.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.default.email}"
}


#######################################
# Cloud Functions
resource "google_cloudfunctions_function" "calendar" {
  name         = "calendar"
  runtime      = "python39"
  entry_point  = "calendar"
  trigger_http = true

  service_account_email = google_service_account.default.email

  environment_variables = {
    PROJECT_NAME      = var.project_name
    KEY_RING_LOCATION = google_kms_key_ring.default.location
    KEY_RING_NAME     = google_kms_key_ring.default.name
    KEY_NAME          = google_kms_crypto_key.default.name
  }

  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.source.name
}

# Allows unauthenticated access to the function
resource "google_cloudfunctions_function_iam_member" "calendar_invoker" {
  project        = google_cloudfunctions_function.calendar.project
  region         = google_cloudfunctions_function.calendar.region
  cloud_function = google_cloudfunctions_function.calendar.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_cloudfunctions_function" "encrypt" {
  name         = "encrypt"
  runtime      = "python39"
  entry_point  = "encrypt"
  trigger_http = true

  service_account_email = google_service_account.default.email

  environment_variables = {
    PROJECT_NAME      = var.project_name
    KEY_RING_LOCATION = google_kms_key_ring.default.location
    KEY_RING_NAME     = google_kms_key_ring.default.name
    KEY_NAME          = google_kms_crypto_key.default.name
  }

  source_archive_bucket = google_storage_bucket.source.name
  source_archive_object = google_storage_bucket_object.source.name
}

# Allows unauthenticated access to the function
resource "google_cloudfunctions_function_iam_member" "encrypt_invoker" {
  project        = google_cloudfunctions_function.encrypt.project
  region         = google_cloudfunctions_function.encrypt.region
  cloud_function = google_cloudfunctions_function.encrypt.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

#######################################
# Source code
resource "google_storage_bucket" "source" {
  name                        = "${var.project_name}-function-source"
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "source" {
  name   = "function-source-${filemd5("../function-source.zip")}.zip"
  bucket = google_storage_bucket.source.name
  source = "../function-source.zip"
}
