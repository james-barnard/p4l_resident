require 'aws-record'
require 'pr_geohash'
require 'constants'

class Resident
  include Aws::Record
  set_table_name ENV['RESIDENT_TABLE_NAME']

  string_attr  :geohash, hash_key: true
  string_attr  :id,      range_key:  true
  string_attr  :latitude
  string_attr  :longitude
  string_attr  :name
  string_attr  :address
  string_attr  :loaded_at

  def save!
    #p "save!: lat: #{latitude}, long: #{longitude}"
    unless persisted?
      self.geohash = GeoHash.encode(latitude.to_f, longitude.to_f, 6)
      #p "save!: resident.geohash: #{self.geohash}"
    end
    super
  end
end
