require 'net/http'
require 'open-uri'


uri = URI('https://tempus.freshsales.io/api/leads/view/2001098583')

Net::HTTP.start(uri.host, uri.port,   
  :use_ssl => uri.scheme == 'https') do |http|
  request = Net::HTTP::Get.new uri
  request['Authorization'] = "Token token=LtIxnBMTEhXETcneawvqIw"
  
  @response = http.request request # Net::HTTPResponse object 
end 
p @response
puts @response.body
