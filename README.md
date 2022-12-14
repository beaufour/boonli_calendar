# Boonli Calendar

[![pre-commit](https://github.com/beaufour/boonli_calendar/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/beaufour/boonli_calendar/actions/workflows/pre-commit.yml)

This project allows you to see the food you have chosen in [Boonli](https://boonli.com/) in your Calendar app (like Google Calendar, Apple Calender, Outlook etc). That way you can easily see what is served for lunch each day.

Try it out for yourself here: <https://boonli.vovhund.com/>

## Motivation

Why did I do this? It was a fun little project that allowed me to poke a bit at both Terraform and Google Cloud functions. As a bonus I can easily see what my daughter is eating each day at school :)

## Behind the Scenes

The project uses the [Boonli API](https://github.com/beaufour/boonli_api) (which really is just doing web scraping) to expose a URL that returns three weeks of menu data in iCalendar format. Boonli doesn't have an API, so we have to use your username and password directly. So to keep some modicum of security, we encrypt the login details so that it's not exposed directly in the URL itself at least. The shared secret is only stored in Google Cloud KMS.

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

* Enable the necessary APIs [here](https://console.cloud.google.com/apis/enableflow?apiid=compute.googleapis.com,oslogin.googleapis.com,dns.googleapis.com,cloudkms.googleapis.com,cloudfunctions.googleapis.com,cloudbuild.googleapis.com)
* Supply credentials (Terraform will give you the instructions if needed)
* Edit `terraform/variables.tf` so they match your setup
* Run `terraform init`
* Run `terraform apply`

Note that it seems like, the Terraform Google Cloud provider doesn't quite understand the dependencies on the Network Endpoint Group, so if you change that you'll have to remove all the whole setup and reapply manually (or I have a bug in the Terraform code...).

You will need your own domain to host it on. The domain you use needs to be specified in `terraform/variables.tf` and `boonli_calendar/encrypt.py`.

## Local Development

You can run the `calendar` function with:

    > ./local_run.sh

and the `encrypt` function with:

    > ./local_run.sh encrypt

That will start them on port 8080 and 8081 respectively.

You can spin up a local nginx server with

    > nginx -c nginx.conf -p .

And then hit <http://localhost:8000/>.
