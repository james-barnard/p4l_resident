# Asset Driver

A serverless bot that can listen for events from AWS S3 buckets when files are created, check them to see if they match a pattern, and then do whatever you need it to do if so.

The bot adds a feature to S3 buckets that's like the "rules" feature in your email app.  In pseudocode, each email rule says something like this:

    if email.subject.contains? "BUY NOW"
    then email.mark_as_junk

Each rule checks to see if the email matches the rule, and if it does then the mail rule does something.  In general terms, this is [predicate-logic](https://en.wikipedia.org/wiki/Predicate_(mathematical_logic)).

The serverless Asset Driver bot adds a system of rules like that, each with triggers and actions, to AWS S3 buckets.  For triggering the processing of asset files when source files are added or updated.  You might need to process your original images into different resolutions and aspect ratios for [serving responsive images](https://developer.mozilla.org/en-US/docs/Learn/HTML/Multimedia_and_embedding/Responsive_images) through `srcset` and `sizes`.  Maybe you need to process video or audio files but you want something simpler than [AWS Elastic Transcoder](https://aws.amazon.com/elastictranscoder/).  Maybe you just want to be notified in Slack when someone deposits a new image in an S3 bucket.  This project is a minimal framework to give you a platform for doing things like that.

Both the rule and the action are simply Ruby code.  To add or modify rules, iterate the code for the project and use standard AWS deployment techniques.  The application doesn't use any storage other than the S3 buckets, so it's simple to operate and maintain.

## How it works

Asset Driver is an [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) application with a [simple Lambda function](https://github.com/VenueDriver/asset-driver/blob/production/lambda.rb) that loads a set of rules and runs them.  It includes [IaC](https://en.wikipedia.org/wiki/Infrastructure_as_code) code for using [AWS CloudFormation](https://aws.amazon.com/cloudformation/) (through SAM) to [do deployments](https://github.com/VenueDriver/asset-driver/blob/production/template.yaml), and also a [script](https://github.com/VenueDriver/asset-driver/blob/production/link.rb) for setting up existing S3 buckets to send messages to the Lambda function.

The Lambda function iterates through the list of rules that the Ruby files in `rules/` have registered.  Each rule is an instance of a Ruby class, containing a `trigger` action that accepts an AWS Lambda event as a paramter, and a `test` event that runs Minitest tests on that rule's logic.  Each rule's `trigger` method checks the AWS Lambda event to see if the event matches whatever pattern the rule cares about.  If a rule matches, then it can perform any action.

For example, if the event is for the creation of a new image source file in a source bucket that matches a certain name pattern, then the action could be to process that source image into various resolutions for serving for a web page or web app.  The Ruby files in `rules/` can use any parameters that you would like to add to the [SAM template](https://github.com/VenueDriver/asset-driver/blob/production/template.yaml).  So, if you want to detect files in one S3 bucket and write them to another bucket, then you can add an additional parameter to the template, specify a bucket name for each environment (`dev`, `staging`, `production`) in the [SAM configuration](https://github.com/VenueDriver/asset-driver/blob/production/samconfig.toml), and then use that bucket name or other rule-specific configuration in your Ruby code for your rule.  As in [this example](https://github.com/VenueDriver/asset-driver/blob/production/rules/venue_driver_flyers.rb) of a rule that writes processed file output to a second S3 bucket.  You can add parameters with ARNs for SQS queues or SMTP information or Slack API information, or anything else that you might need.

## Deploying

With SAM, you have to build before you can deploy:

    $ sam build

That bundles the Ruby gems and creates the stuff for SAM to upload to the deployment S3 bucket when you deploy.

SAM can't bind an S3 event to a Lambda function unless the S3 bucket is from the same SAM template.  It can't work with existing buckets.  That means that we need to do some additional work after the SAM deployment to set up the S3 events to trigger the Lambda function.  To run the script that handles all of it:

    $ ruby deploy.rb

That will deploy the default environment, which is set up to use a development bucket for input and output.  The bucket must exist already, and the bucket setup is not handled by this SAM template.

You can optionally pass an environment:

    $ ruby deploy.rb staging
    $ ruby deploy.rb production

### CI

If you want control over SAM so that you can do a canary deployment or something, then you can do this instead:

    $ sam deploy

Pass the environment with the `--config-env` option, like this:

    $ sam deploy --config-env=staging
    $ sam deploy --config-env=production

## Linking S3 buckets to Lambda functions

Deploying only deploys the Lambda functions.  If it's the first deployment, then you might also need to set up the S3 buckets to trigger Lambda events.  You can do that with:

    $ ruby link.rb

Do it for specific environments with:

    $ ruby link.rb staging
    $ ruby link.rb production

The script deploys using SAM, then checks the outputs of the stack to find the ARN for the Lambda function that it just deployed.  Then it uses that to set up the event on the S3 buckets.  The names for the S3 buckets are passed through the SAM template parameters into the stack, and will also appear in the output.  So, the important configuration information for each stack is available from CloudFormation.  You can configure the names for the specific S3 buckets that that you want to use in the [`samconfig.toml` file](https://github.com/VenueDriver/asset-driver/blob/production/samconfig.toml).

## Development

You can invoke the Lambda function locally like this:

    sam local invoke RunRules --event tests/events/created_file.json

You will need to deploy the default environment to create the S3 buckets for the `dev` stack first before you'll be able to do much.

Don't forget to `sam build` first, or you'll confuse yourself by looking at output from a previous version of your code.  Like Amazon mentions in the [documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-cli-command-reference-sam-build.html) for `sam build`, you might as well make a policy of doing this:

    sam build && sam local invoke RunRules --event tests/events/created_file.json

## Rules

The rules are set up in Ruby files in `rules/`.  Each file can register one or more rules by adding them to a global `$rules` array.  The Lambda function that handles S3 events takes the event and passes it to the `trigger` method of each rule in the list.

Here's an example of a rule that doesn't do anything, it just prints logging information to the console when it's called:

    def trigger(event:)
      $logger.info 'Hello, world!'
      $logger.debug "AWS Lambda event: " + event.ai
    end

One way to write your rules is to deploy something like that and trigger events and then look at them in the CloudWatch logs.  So that you can write the code for examining the events.

Here's an example of a rule that checks the event to see if it matches some pattern:

    def trigger(event:)
      event = event[:event]['Records'].first
      if event['eventSource'].eql? 'aws:s3' and
        event['eventName'].eql? 'ObjectCreated:Put'
        $logger.info "File name: #{event['s3']['object']['key']}"
      end
    end

## Tests

To run the tests:

    ruby test.rb

That will find all of the test for all of the rules in the project, and run them.

To run the tests in SAM Local, the way that they would run in the cloud:

    sam build && sam local invoke sam build && sam local invoke PreTrafficLambdaFunction

You can use that same `PreTrafficLambdaFunction` as a canary in an AWS CodeDeploy deployment.  It uses real S3 buckets for storing files during tests.

Each rule file in `rules/` can have a corresponding file in `tests/` with any kind of unit testing that you want.  The canary AWS Lambda function that runs as the `PreTrafficLambdaFunction` will call each `test` method in each rule instance during pre-deployment testing and also when using canary testing during deployment with AWS Clode Deploy.  [For example](https://github.com/VenueDriver/asset-driver/blob/production/tests/venue_driver_flyers.rb), you can use [Test::Unit](https://www.rubydoc.info/gems/test-unit/2.3.1/Test/Unit) tests in your rule.  You could probably also use MiniTest.  Or RSpec.  Or whatever you like.

## Operation

The AWS control panel for the CloudFormation service is your starting point for operations.  That's where you will find the stacks that you have deployed using SAM.  And that's where you can find links to the resources in those stacks.

### Logging

You can see logs of the activity from your Lambda function by finding the Lambda function in the "resources" section of the CloudFormation stack.  The Lambda function will have a link in its "monitoring" section to the CloudWatch logs.  You can adjust the granularity of the log information by adjusting `$logger.level`, [here](https://github.com/VenueDriver/asset-driver/blob/production/lib/logger-setup.rb#L4).

### TODO

The `link.rb` script doesn't grant permissions to the relevant S3 buckets for the IAM role that the Lambda function uses.  It probably should.  Ugly and insecure workaround: Grant the `AmazonS3FullAccess` permission policy to the IAM role for the Lambda function.

The code doesn't necessarily know the name or ARN of the source bucket.  So you can either manually grant read access to the source bucket, or maybe all buckets in the account.
