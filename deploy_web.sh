#!/bin/bash
#
# Syncs the web site contents to the GCS bucket
#
gsutil rsync -R web/ gs://boonli-menu-website-bucket
