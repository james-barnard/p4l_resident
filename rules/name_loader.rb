require 'aws-record'
require 'geocodio'
require 'pdf_data_file'
require 'resident'
require 'aws-sdk-s3'

$user_state = 'TN' #todo: fix this if we deploy for !TN
$user_state = 'OK' #todo: fix this if we deploy for !TN

class NameLoader < Rule

  #-----------------------------------------------------------------------------
  # Rule
  #-----------------------------------------------------------------------------

  def trigger(event:)
    $logger.info "AWS Lambda event:\n #{event}"

    event = event['Records'].first
    puts "trigger: #{event}"

    $logger.info "Bucket name: #{event['s3']['bucket']['name']}"
    $logger.info "File name: #{event['s3']['object']['key']}"

    if (
        event['eventSource'].eql? 'aws:s3' and
        event['eventName'].eql? 'ObjectCreated:Put' and
        event['s3']['object']['key'] =~ /(.*pdf)/
      )
      @source_bucket = "#{event['s3']['bucket']['name']}"
      @load_file     = "#{event['s3']['object']['key']}"
      @loaded_bucket = ENV['PRAYER_LIST_LOADED_BUCKET']
      @loaded_count = 0
      @failed_count = 0

      $logger.debug "trigger: filename: #{@load_file}"

      @user_city = city_from_file_name @load_file
      load_s3_file(
        bucket:   event['s3']['bucket']['name'],
        filename: @load_file
      )
    else
      $logger.info "Did not meet trigger conditions."
    end
  end

  def city_from_file_name filename
    filename =~ /t(\d.*)-(\d.*)\.pdf/
    geocodio.reverse_geocode(["#{$1},-#{$2}"]).best.city
  end

  def s3_resource
    @client ||= Aws::S3::Resource.new()
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: ENV['S3_REGION'] #,
      #credentials: credentials,
    )
  end

  def geocodio
    @geocodio ||= Geocodio::Client.new(ENV['GEOCODIO_API_KEY'])
  end

  def pdf_file
    "/tmp/pdf_file"
  end

  def data_file
    "/tmp/data_file"
  end

  def archive_load_file
    s3_client.copy_object(
      bucket: @loaded_bucket,
      copy_source: "#{@source_bucket}/#{@load_file}",
      key: "#{@load_file}.#{Time.now.to_i}",
    )
    $logger.info "archive_load_file: #{@source_bucket}/#{@load_file} archived"
  end

  def remove_load_file
    s3_client.delete_object(bucket: @source_bucket, key: @load_file)
    $logger.info "remove_load_file: #{@source_bucket}/#{@load_file} removed"
  end

  def geocode addr
    geocodio.geocode(localize(addr)).first.best
  end

  def localize addr
    "#{addr}, #{@user_city}, #{$user_state}"
  end

  def tokenize str
    if str.nil? || str.size < 1
      ''
    else
      alphanum_str = str.gsub! /\W/, ' '

      words = alphanum_str.split.select {|w| 'and' != w}

      tokens = words.collect {|w| w[0..2]}
      tokens.join
    end
  end

  def matchkey name, address
    tokenize(name) + tokenize(address)
  end

  def  load_resident(line)
    name, addr = line.split '|'
    address = geocode addr
    unless address.nil?
      begin
        now = Time.now
        resident = Resident.new(
          id:        matchkey(name, addr),
          name:      name,
          address:   addr,
          latitude:  address.latitude.to_s,
          longitude: address.longitude.to_s,
          loaded_at: now.strftime('%F %R')
        )
        resident.save!
        @loaded_count += 1
        $logger.info "loading: #{resident.name}, #{resident.address}"
      rescue  Aws::DynamoDB::Errors::ServiceError => error
        @failed_count += 1
        $logger.info "#{error.message}: #{name}, #{addr}, id: #{matchkey(name,addr)}"
      rescue Aws::Record::Errors::ConditionalWriteFailed => error
        @failed_count += 1
        $logger.info "#{error.message}: #{name}, #{addr}, id: #{matchkey(name,addr)}"
      end
    end
  end

  def load_s3_file(bucket:, filename:)
    $logger.info "load_s3_file: bucket: #{bucket} key: #{filename}"

    object = s3_resource.bucket(bucket).object(filename)
    object.get(response_target: pdf_file)

    data_file = PdfDataFile.new(pdf_file)

    data_file.records.each do |record|
      next if @loaded_count > 1
      load_resident record
    end

    archive_load_file
    remove_load_file
    $logger.info "load_s3_file: #{bucket}/#{filename} loaded: #{@loaded_count}"
    $logger.info "load_s3_file: #{bucket}/#{filename} failed: #{@failed_count}"
    $logger.info "name_loader: RULE COMPLETE"
  end

end

# Register an instance of the rule in the global list.
$rules << NameLoader.new
