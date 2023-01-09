# P4L Resident Driver

This project uses "asset driver" to trigger one or more rules to fire
when a P4L user uploads a file to S3.

## See asset driver readme for How it works

## Deploying

    $ sam build

    $ sam deploy 

      Use the --guided flag the first time to define the environment variables the lambda will need to operate.  These ENV vars include:
        * S3_REGION
        * PRAYER_LIST_NAMES_BUCKET
        * PRAYER_LIST_LOADED_BUCKET
        * RESIDENT_TABLE_NAME
        * AWS_EXECUTION_ENV
        * GEOCODIO_API_KEY

- Go to https://www.geocod.io/ to get an api key.  Geocoding one address
at a time should be free up to 2500 requests per day.

- Make sure lambdas, s3 buckets, and ddb database tables are in the same
region.
