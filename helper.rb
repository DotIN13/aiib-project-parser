require 'rubygems'
require 'pdf/reader'

SUMMARIES_DIR = 'projects/summaries/'.freeze
DOCUMENTS_DIR = 'projects/documents/'.freeze
SEPARATOR = "--------------------------\n".freeze

class Files
  def self.iterate(folder)
    Dir.children(folder).sort.each do |file|
      next if ['.', '..', '.DS_Store'].include?(file)

      yield(file)
    end
  end
end

class String
  def linebreak!
    self << "\n"
  end
end

class AIIBReader < PDF::Reader
  attr_accessor :matched

  def initialize(input, opts = {})
    super(input, opts)
    @error_handler = ErrorHandler.new(opts[:error_log], input)
    @width = column_width(opts[:attribute_pattern])
    @matched = []
  end

  def column_width(regex)
    pages.first.text.match(regex)[1].length - 1
  rescue NoMethodError => e
    @error_handler.handle(e)
    0
  end

  def find_row(start)
    start = start.dup
    pages[start[:page]..-1].each_with_index do |page, page_index|
      lines = page.text.split("\n")
      start[:line] = 0 unless page_index.zero?
      lines[start[:line]..-1].each_with_index do |line, line_index|
        raw = line[0..@width]
        return { page: page_index + start[:page], line: start[:line] + line_index, match: line } if yield(raw)
      end
    end
    false
  end

  # Input the pattern of attribute cell
  def extract_cell_with_attr(pattern, start = {page: 0, line: 0})
    match_start = find_row(start) do |raw|
      pattern.any? { |pat| raw.include?(pat) }
    end
    raise StandardError, 'No match for given pattern' unless match_start

    match_end = find_row(match_start) do |raw|
      # Debugger for row end
      # Match if line contains (@width - 5) whitespaces
      # and not containing any of the excluded words
      # puts "LINE '#{raw}'"
      # puts "passed with #{pattern.all? { |ex| !raw.include?(ex) }} & #{raw.strip.length >= 5}"
      pattern.all? { |ex| !raw.include?(ex) } && raw.strip.length >= 3
    end
    raise StandardError, 'Unable to find the next cell' unless match_end

    puts 'Match found'
    matched << match_start.merge(content: populate(match_start, match_end))
    extract_cell_with_attr(pattern, match_end)
    matched
  rescue StandardError => e
    @error_handler.handle(e)
    []
  end

  # Input two hashes of line index and return all content in between
  def populate(start, finish)
    pages[start[:page]..finish[:page]].map do |page|
      page_index = page.number - 1
      start[:line] = 0 unless page_index == start[:page]
      extract_start = start[:line].positive? ? start[:line] - 1 : start[:line]
      extract_finish = page_index == finish[:page] ? finish[:line] : -1
      page.text.split("\n")[extract_start..extract_finish].join("\n")
    end.join("\n")
  end
end

class Interface
  def parse(result)
    return 'No data retrieved, please refer to the original document.' unless result

    result.map do |item|
      output = "Page: #{item[:page]}".linebreak!
      output << "Line:#{item[:line]}".linebreak!
      output << item[:content].linebreak!
    end.join(SEPARATOR)
  end
end

class ErrorHandler
  def initialize(log, file)
    @log = log
    @file = file
  end

  def handle(err)
    puts err.message
    File.write(@log, "#{err.class} Error processing #{@file}: #{err.message}\n", mode: 'a')
  end
end
