require 'ostruct'

module P4L
  class Constants
    def self.config(*params)
      @config ||= initialize(*params)
    end

    private
    def self.initialize(stage: "Prod")
      base_configuration = {
        stage:                     stage,
        region:                    'us-east-1',
        p4l_resident_names:        'p4l.resident.names',
        p4l_resident_names_loaded: 'p4l.resident.names.loaded',
        geo_codio_api_key:         '88033e6380f5a60f3a3663a0dff00655aade60a'
      }

      config = if stage == "Prod"
        base_configuration.merge('table_name' => "P4L.residents")
      else
        base_configuration.merge(
          table_name:  "test.p4l.residents"
        )
      end

      OpenStruct.new(config)
    end
  end
end
