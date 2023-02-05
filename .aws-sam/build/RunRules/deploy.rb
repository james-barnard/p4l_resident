environment = ARGV[1] || 'dev'

puts "Environment: #{environment}"

system("sam deploy --config-env=#{environment}")
