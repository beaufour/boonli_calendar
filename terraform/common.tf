##################################################
# Monitoring
#
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification Channel"
  type         = "email"
  labels = {
    email_address = "booonli_calendar@vovhund.com"
  }
}
