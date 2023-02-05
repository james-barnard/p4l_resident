require 'aws-record'
require 'geocodio'
require 'pdf_data_file'
require 'resident'
require 'resident_log'
require 'aws-sdk-s3'

$user_state = 'TN' #todo: fix this if we deploy for !TN
# $user_state = 'OK' #todo: fix this if we deploy for !TN

class NameLoader < Rule

  #-----------------------------------------------------------------------------
  # Rule
  #-----------------------------------------------------------------------------

  def trigger(event:)
    $logger.debug "AWS Lambda event:\n #{event}"

    event = event['Records'].first
    puts "trigger: #{event}"

    $logger.debug "Bucket name: #{event['s3']['bucket']['name']}"
    $logger.debug "File name: #{event['s3']['object']['key']}"

    if (
        event['eventSource'].eql? 'aws:s3' and
        event['eventName'].eql? 'ObjectCreated:Put' and
        event['s3']['object']['key'] =~ /(.*pdf)/
      )
      @source_bucket  = "#{event['s3']['bucket']['name']}"
      @load_file      = "#{event['s3']['object']['key']}"
      @loaded_bucket  = ENV['PRAYER_LIST_LOADED_BUCKET']
      @loaded_count   = 0
      @failed_count   = 0
      @error_occurred = false

      $logger.debug "trigger: filename: #{@load_file}"

      @user_city, @user_id = file_name_components @load_file
      
      load_s3_file(
        bucket:   event['s3']['bucket']['name'],
        filename: @load_file
      )
    else
      $logger.info "Did not meet trigger conditions."
    end
  end

  def log_results
    ResidentLog.new(
      timestamp: now.to_i,
      file_name:  @load_file,
      loaded:    @loaded_count,
      failed:    @failed_count,
      loaded_at: now.strftime('%F %R')
    ).save!
  end

  def file_name_components filename
    filename =~ /t(\d.*)-(\d.*)-u(.*)-d(.*)\.pdf/
    [geocodio.reverse_geocode(["#{$1},-#{$2}"]).best.city, $3]
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

  def now
    Time.now
  end

  def archive_load_file
    s3_client.copy_object(
      bucket: @loaded_bucket,
      copy_source: "#{@source_bucket}/#{@load_file}",
      key: "#{@load_file}.#{now.to_i}",
    )
    $logger.debug "archive_load_file: #{@source_bucket}/#{@load_file} archived"
  end

  def remove_load_file
    s3_client.delete_object(bucket: @source_bucket, key: @load_file)
    $logger.debug "remove_load_file: #{@source_bucket}/#{@load_file} removed"
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

  def format_user_id(user_id)
    user_id.sub /-d/, "@"
  end

  def  load_resident(line)
    name, addr = line.split '|'
    address = geocode addr
    unless address.nil?
      begin
        resident = Resident.new(
          user_id:   format_user_id(@user_id),
          match_key: matchkey(name, addr),
          name:      name,
          address:   addr,
          latitude:  address.latitude.to_s,
          longitude: address.longitude.to_s,
          loaded_at: now.strftime('%F %R')
        )
        resident.save!
        @loaded_count += 1
        $logger.debug "loading: #{resident.name}, #{resident.address}"
      rescue  Aws::DynamoDB::Errors::ServiceError => error
        @failed_count += 1
        $logger.error "#{error.message}: #{name}, #{addr}, id: #{matchkey(name,addr)}"
      rescue Aws::Record::Errors::ConditionalWriteFailed => error
        @failed_count += 1
        $logger.error "#{error.message}: #{name}, #{addr}, id: #{matchkey(name,addr)}"
      end
    end
  end

  def retrieve_s3_file
    $logger.debug "retrieve_s3_file: #{@source_bucket}/#{@load_file}"

    begin
      object = s3_resource.bucket(@source_bucket).object(@load_file)
      object.get(response_target: pdf_file)

    rescue  Aws::S3::Errors::NoSuchKey => error
      $logger.error "retrieve_s3_file: #{error.message}: #{@source_bucket}/#{@load_file}"
      @error_occurred = true
    end
  end

  def load_s3_file(bucket:, filename:)
    $logger.debug "load_s3_file: bucket: #{bucket} key: #{filename}"

    retrieve_s3_file

    data_file = PdfDataFile.new(pdf_file)

    unless @error_occurred
      data_file.records.each do |record|
        next if @loaded_count > 1
        next if @failed_count > 1
        load_resident record
      end

      archive_load_file
      remove_load_file
    end

    log_results
    $logger.info "load_s3_file: #{bucket}/#{filename} loaded: #{@loaded_count}"
    $logger.info "load_s3_file: #{bucket}/#{filename} failed: #{@failed_count}"
    $logger.info "name_loader: ******************** RULE COMPLETE ********************"
  end
end

# Register an instance of the rule in the global list.
$rules << NameLoader.new
