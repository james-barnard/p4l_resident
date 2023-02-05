class StackInfo

  attr :environment

  def initialize(environment:)
    @environment = environment
    @data = JSON.parse(
      `aws cloudformation describe-stacks --stack-name=asset-driver-#{environment}`)
  end

  def getOutputValue(name:)
    @data['Stacks'][0]['Outputs'].
      select{ |output| output['OutputKey'].eql? name }[0]['OutputValue']
  end

end
