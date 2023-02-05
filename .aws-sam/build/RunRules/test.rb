$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'logger-setup'
require 'sam-parameter-environment'
SamParameterEnvironment.load

environment = ARGV[1] || 'dev'

puts "Environment: #{environment}"

# Load all rules.
$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'rules'

# Add the test code to the rules by loading that extra code.
Dir.glob("tests/**/*.rb").each{|file| require_relative "#{file}" }

$logger.info 'Running tests...'

$rules.each{ |rule| rule.test }
