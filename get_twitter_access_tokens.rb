require 'rubygems'
require 'twitter'
require 'yaml'

config = YAML::load(File.open('config.yaml'))
oauth = Twitter::OAuth.new(config['token'], config['secret'])
rtoken = oauth.request_token.token
rsecret = oauth.request_token.secret

puts "Surf to the follwoing url"
puts oauth.request_token.authorize_url

print "Enter PIN provided after granting access > "
pin = gets.chomp

begin

  oauth.authorize_from_request(rtoken, rsecret, pin)
  atoken = oauth.access_token.token
  asecret = oauth.access_token.secret
  puts "Place the following lines in config.yaml"
  puts "atoken: #{atoken}"
  puts "asecret: #{asecret}"

rescue OAuth::Unauthorized

  puts "Error"

end
