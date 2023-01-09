require 'pdf/reader' # gem install pdf-reader

$anti_patterns = [
  /^$/,
  /blesseveryhome.com/,
  /Neighborhood List/,
  /pray.*care/,
  /this page/,
  /groups of/,
  /^It is/,
  /^sources/,
  /Powered by TCPDF/
]

class PdfDataFile
  def initialize(filename)
    @pdf_file = filename
    @raw_txt_file = Tempfile.new 'raw_text'
    PDF::Reader.open(@pdf_file) do |reader|
      reader.pages.map { |page| @raw_txt_file.write(page.text) }
    end
	end

  def anti_pattern(str)
    txt = str.strip
    #p "anti-pattern: str: [#{str}] txt: [#{txt}] length: #{txt.length}"
    $anti_patterns.any? {|p| p =~ txt}
  end
  "anti-pattern: str: [pray                 care                  share                  disciple] txt: [pray                 care                  share                  disciple] length: 74"


  def is_addr(str)
    txt = str.strip
    txt =~ /\d/
  end

  def records
    @raw_txt_file.rewind
    name = 'name'
    list = []
    @raw_txt_file.each do |line|
      line = line.chomp.strip
      next if anti_pattern(line)
      #p "line: |#{line}|"
      if is_addr(line)
        list << "#{name}|#{line}"
      else
        name = line
      end
    end
    list
  end
end
