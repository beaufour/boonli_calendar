# Boonli Calendar

This project uses the Boonli API to expose an API that returns the Boonli menu chosen as an iCalendar.

## Local development

You can run the function locally with:

    > ./local_run.sh

## Deploying

You can deploy the calendar Cloud Function like this:

    > gcloud functions deploy calendar --gen2 --runtime=python39 --entry-point=calendar --trigger-http --allow-unauthenticated

This assumes that you have set up the default project using `gcloud config set project PROJECT_ID`.

You can then hit the deployed URL (will be output by the `gcloud` command above) with `?username=...&password=...&customer_id=...` and it will return the iCalendar.

## Full Infrastructure

To deploy both functions (calendar API and the encrypt function) on a custom domain, use [Terraform](https://www.terraform.io/) config [terraform](terraform).

First, build up the source zip with:

    > ./build.sh

And then run Terraform:

* Enable the necessary APIs [here](https://console.cloud.google.com/apis/enableflow?apiid=compute.googleapis.com,oslogin.googleapis.com)
* Supply credentials (Terraform will give you the instructions if needed)
* Edit `terraform/variables.tf` so they match your setup (and potentially `terraform/main.tf` too)
* Run `terraform init`
* Run `terraform apply`

Note that it seems like, the Terraform Google Cloud provider doesn't quite understand the dependencies on the Network Endpoint Group, so if you change that you'll have to remove all the whole setup and reapply manually (or I have a bug in the Terraform code...).
