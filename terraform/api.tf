#
# Setup for the API endpoints
#
# Note: There's also a 2nd gen Cloud Functions, but I've only had trouble with
# it. Either because it's fairly new or because Terraform doesn't handle it
# well. Or both...
#

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
