require 'rubygems'
require 'twitter'
require 'yaml'
require 'mechanize'
require 'nokogiri'
require 'bitly'

class String
  def no_html
    self.gsub(/<.*?>/, " ").gsub(/[\r\n\t]/, "").gsub(/\s{2}+/, "").gsub(/^\s*/,"").gsub(/\s*$/,"")
  end
end



fridge_root = 'http://www.frid.ge/php/'
fridge_url = "#{fridge_root}/home.php?g="

config = YAML::load(File.open('config.yaml'))

while true 

  agent = Mechanize.new   
  agent.user_agent = 'fridge_to_twitter'

  login_page = agent.get("http://frid.ge")
  login_page.form_with(:name => 'loginForm') do |f|
    f.email = config['fridge_email']
    f.password = config['fridge_password']
  end.submit
       
  tweets = []
  tweets = YAML::load(File.open(config['recent_tweets'])) if File.exists?(config['recent_tweets'])
  puts "Tracking #{tweets.size} messages"

  page = agent.get("#{fridge_url}#{config['fridge_id']}")       
  doc = Nokogiri::HTML(page.body)
  content = doc.xpath("//div[@id='rightcolumn']")
  content.children.each do |post|
    author = post.xpath("div[2]/div[1]/div[1]/a[contains(@href,'profile')]")
    next unless author.size>0
    author= author.inner_html.no_html.gsub(/ .*$/,'')
    update = post.xpath("div[2]/div[2]")
    update= update.inner_html.no_html 
    images = post.xpath("div[2]/div//img[contains(@class,'photo')]/..")
    photo=nil
    images.each do |image|
      photo = image.attributes['href'] if image
    end
    
    Bitly.use_api_version_3
    bitly = Bitly.new(config['bitly_username'], config['bitly_api_key'])
    url = bitly.shorten(fridge_root+photo) if photo
    update_size = 140 - author.size - 3
    update_size = update_size - 1 - url.short_url.size if url
 
    tweet = update[0,update_size]
    tweet += " #{url.short_url}" if photo
    tweet += " (#{author})"
    
    next if tweets.include?(tweet)
    tweets.shift if tweets.size>25 
    tweets << tweet 

    begin
      oauth = Twitter::OAuth.new(config['token'], config['secret'])
      oauth.authorize_from_access(config['atoken'], config['asecret'])
      base = Twitter::Base.new(oauth)
    rescue
      sleep 5*60
      next
    end

    begin
      puts "New: #{tweet}"
      base.update(tweet)
    rescue
      puts "Error updating"
      sleep 5*60
      next
    end

  end

  File.open(config['recent_tweets'], 'w+') { |f| YAML.dump(tweets, f) }

  sleep config['sleep_in_seconds'].to_i

end

