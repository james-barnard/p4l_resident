require 'logger'

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
$logger.formatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
end
