$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'logger-setup'
#require 'sam-parameter-environment'
#SamParameterEnvironment.load

# Load all rules.
$logger.debug `bundle env`
require 'rules'

def run_rules(event:, context:)

  $logger.info 'Running rules...'

  $rules.each{ |rule| rule.trigger(event:event) }

  {
    statusCode: 200
  }

end
