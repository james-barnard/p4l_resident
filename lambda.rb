$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'logger-setup'
#require 'sam-parameter-environment'
#SamParameterEnvironment.load

# Load all rules.
$logger.info `bundle env`
require 'rules'

# Unit tests, can be run as canaries in the cloud.
def pre_traffic_lambda_function(event:, context:)
  # Each canary within this AWS Lambda function is a labmda function in Ruby.
  $rules.each{ |rule| rule.test }
end

# AWS Lambda function handler.
def run_rules(event:, context:)

  $logger.info 'Running rules...'

  $rules.each{ |rule| rule.trigger(event:event) }

  {
    statusCode: 200
  }

end
