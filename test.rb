require 'mechanize'
require 'json'

class GeniusParser
  ACCESS_TOKEN = 'Bearer sHBj63vrkY60lT73XLkbkfT2eAEzevTnyViGu2W6Bjlv9Z4CmNBHHd4pZIPew-Nv'.freeze
  DEFAULT_NAME = 'King-of-the-dot'.freeze

  def initialize
    @agent = Mechanize.new
    @songs = []
    @loses = 0
    @wins = 0
  end

  def get_song_urls(name = nil)
    puts 'Please w8 referee.'
    name_for_search = name || DEFAULT_NAME

    page_num = 1
    loop do
      request = "https://api.genius.com/search?q=#{name_for_search}&per_page=20&page=#{page_num}"
      response = @agent.get(request, [], nil, { 'Authorization' => ACCESS_TOKEN }).body
      response_json = JSON.parse(response)

      break if response_json.dig('response', 'hits').empty?

      @songs << response_json.dig('response', 'hits').map do |s|
        if /(vs | vs\.)/ =~ s['result']['title']
          if name.nil?
            s['result']
          else
            s['result'] if Regexp.new(name) =~ s['result']['title']
          end
        end
      end
      page_num += 1
    end

    @songs.flatten!.compact!
  end

  def referee(name = nil, criteria = nil)
    get_song_urls(name)

    @songs.each do |song|
      song_text = @agent.get(song['url']).search('.lyrics p').text

      begin
        opponents_results = RapParser.new(song_text, criteria).split_opponents
      rescue
        next
      end

      puts "#{song['title']} - #{song['url']}"

      results(opponents_results, name)
    end

    puts "#{name} wins #{@wins}, loses #{@loses} times" if !name.nil?
  end

  def results(opponents_results, name)
    opponents_results.each do |opponent|
      puts "#{opponent[:name]} - #{opponent[:criteria_count]}"
    end

    opponent_num = if !name.nil?
      Regexp.new(name) =~ opponents_results[0][:name] ? 0 : 1
    else
      nil
    end

    result_with_score(opponents_results, opponent_num)

    puts
  end

  def result_with_score(opponents_results, opponent = nil)
    if opponents_results[0][:criteria_count] > opponents_results[1][:criteria_count]
      @wins += 1 if opponent == 0
      @loses += 1 if opponent == 1

      puts "#{opponents_results[0][:name]} - WINS!"
    else
      @wins += 1 if opponent == 1
      @loses += 1 if opponent == 0

      puts "#{opponents_results[1][:name]} - WINS!"
    end
  end
end

class RapParser
  def initialize(song_text, criteria = nil)
    @song_text = song_text
    @criteria = criteria
    @first_opponent = { text: '' }
    @second_opponent = { text: '' }
  end

  def split_opponents
    rounds = @song_text.scan(/\[Round.*?\]/)
    raise if rounds.size != 6
    @first_opponent[:name] = rounds[0].split(':')[1].gsub(/\W+/, ' ').strip
    @second_opponent[:name] = rounds[1].split(':')[1].gsub(/\W+/, ' ').strip
    texts = @song_text.split(/(\[Round.*?\])/)
    texts.shift
    first_indexes = [1,5,9]
    second_indexes = [3,7,11]
    texts.each_with_index do |text, index|
      if first_indexes.include? index
        @first_opponent[:text] << text
      elsif second_indexes.include? index
        @second_opponent[:text] << text
      end
    end
    criteria_result
    [@first_opponent, @second_opponent]
  end

  def criteria_result
    if @criteria.nil?
      @first_opponent[:criteria_count] = @first_opponent[:text].gsub(/\W/, '').size.to_i
      @second_opponent[:criteria_count] = @second_opponent[:text].gsub(/\W/, '').size.to_i
    else
      @first_opponent[:criteria_count] = @first_opponent[:text].scan(@criteria).size.to_i
      @second_opponent[:criteria_count] = @second_opponent[:text].scan(@criteria).size.to_i
    end
  end
end

require 'optparse'

class Parser
  def initialize(args)
    @args = args.dup
  end

  def parse
    params = OptionParser.new do |opts|
      opts.banner = 'Usage: ./demo.rb NAME'
    end.parse!(@args)

    find_permit_params(params)
  end

  def find_permit_params(params)
    return {} if params.empty?
    permit_params = {}
    params.each do |param|
      permit_params[:name] = param.match(/NAME=(\w*)/)[1] if param =~ /NAME=(\w*)/
      permit_params[:criteria] = param.match(/CRITERIA=(\w*)/)[1] if param =~ /CRITERIA=(\w*)/
    end
    permit_params
  end
end

params = Parser.new(ARGV).parse
gp = GeniusParser.new
gp.referee(params[:name], params[:criteria])
