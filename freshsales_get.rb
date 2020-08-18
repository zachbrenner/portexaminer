require 'net/http'
require 'open-uri'
require 'json'
require 'csv'

def get_response(url)
	uri = URI(url)
	Net::HTTP.start(uri.host, uri.port, 
	:use_ssl => uri.scheme == 'https') do |http|
  		request = Net::HTTP::Get.new uri
  		request['Authorization'] = "Token token=LtIxnBMTEhXETcneawvqIw"
  		return @response = http.request(request) # Net::HTTPResponse object 
	end 
end

def write_csv(leads)
	CSV.open("datafreshsales.csv","wb") do |csv|
		csv << leads[0]["company"].keys
		@company_count = 0
		leads.each do |lead|
			puts "lead[company]"
			p lead["company"
]			if lead["company"]
				csv << lead["company"].values
				@company_count += 1
			end		
		end
	end
	puts leads.length-@company_count

end


url = 'https://tempus.freshsales.io/api/leads/view/2001098583'

json = get_response(url)
pages = []

first_page = JSON.parse(json.body)
puts "first page"
p first_page["leads"]
leads = first_page["leads"]
num_of_pages = first_page["meta"]["total_pages"]

begin 
(2..num_of_pages).each do |page|
	paginated_url = url + "?page=#{page}"
	puts "getting #{paginated_url}"
	resp = get_response(paginated_url)
	page_leads = JSON.parse(resp.body)["leads"]
	puts "page leads"
	p page_leads
	puts "page leads length"
	p page_leads.length
	leads += page_leads
	puts "length of leads"
	puts leads.length
end

rescue SignalException => e
	write_csv(leads)
end

write_csv(leads)