require './helper'

PATTERN = %w[Cost Plan Commitment].freeze
HASH = Time.now.strftime('%Y%m%dT%H%M').freeze
LOGS = { result: "log/results_#{HASH}.log", error: "log/errors_#{HASH}.log" }.freeze

# Always start with a clean log file
LOGS.each do |_k, file|
  File.delete(file) if File.exist?(file)
end

io = Interface.new

Files.iterate(SUMMARIES_DIR) do |file|
  puts "Processing #{file}"
  reader = AIIBReader.new(SUMMARIES_DIR + file, attribute_pattern: /\n(\s?\w+\sName\s*)/, error_log: LOGS[:error])

  output = ''
  output << SEPARATOR
  output << file.linebreak!
  output << SEPARATOR
  output << io.parse(reader.extract_cell_with_attr(PATTERN))

  File.write(LOGS[:result], output, mode: 'a')
end
