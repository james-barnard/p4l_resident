require 'JSON'
require 'awesome_print'
require 'pry'

require_relative 'lib/stack-info'

environment = ARGV[1] || 'dev'

puts "Environment: #{environment}"

info = StackInfo.new(environment:environment)

puts "Adding a resource policy to allow S3 permission to invoke the function..."

command = <<-COMMAND
  aws lambda add-permission \
    --statement-id "#{rand 99999999}" \
    --function-name "#{info.getOutputValue(name:'RunRules')}" \
    --action "lambda:InvokeFunction" --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::#{info.getOutputValue(name:'VenueDriverFlyersSourceBucket')}"
COMMAND
puts "command: #{command}"
system command

puts "Connecting S3 events to the RunRules Lambda function..."

notification_configuration = <<-JSON
  {
    "LambdaFunctionConfigurations": [
      {
        "Id": "ObjectCreated",
        "LambdaFunctionArn": "#{info.getOutputValue(name:'RunRules')}",
        "Events": [
          "s3:ObjectCreated:*"
        ]
      }
    ]
  }
JSON

puts "configuration: #{notification_configuration}"

command = <<-COMMAND
  aws s3api \
    put-bucket-notification-configuration \
    --bucket "#{info.getOutputValue(name:'VenueDriverFlyersSourceBucket')}" \
    --notification-configuration "#{notification_configuration.gsub(/\"/,'\"')}"
COMMAND

puts "command: #{command}"

system command
