require 'aws-record'

class ResidentLog
  include Aws::Record
  set_table_name ENV['RESIDENT_LOG_TABLE_NAME']

  string_attr  :file_name, hash_key: true
  integer_attr :timestamp, range_key:  true
  integer_attr :loaded
  integer_attr :failed
  string_attr  :loaded_at

end
