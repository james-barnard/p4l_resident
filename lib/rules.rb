class Rule
  def trigger
  end
  def test
  end
  public :trigger, :test
end

$rules = [] # Global list of rule class instances.
Dir.glob("rules/**/*.rb").each{|file| require_relative "../#{file}" }
