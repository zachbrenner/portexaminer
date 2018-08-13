require 'open-uri'
require 'thread'
require 'csv'
class SearchController < ApplicationController
	Shipment = Struct.new(:keyword, :count,:url, :shipper, :consignee, :origin, :destination, :date)
  def index
  	
  end
  def search
  	tn = Time.now
  	@keywords = params[:keywords].split(",").reverse
	puts params
	@remove_subs_was_checked = false
	@removed_subsidiaries = false
	if params[:remove_subsidiaries]
		@remove_subs_was_checked = true
	else
		@remove_subs_was_checked = false
	end
	puts "Searching for #{@keywords}"
  	
  	
  	if params[:deep_search]
  		@chart = deep_search(@keywords)
  	else
  		@chart = scrape_results(params[:search_type],@keywords)	

  end


  	@t = Time.now - tn
	@file_name = (Time.new.strftime("%I:%M%p %m-%d-%Y-") + rand(1000..9999).to_s + ".csv")
	generate_csv(@file_name)
  end	

  def generate_csv(file_name)
	CSV.open("#{Rails.root}/public/#{file_name}","wb") do |csv|
		csv << ["Cosignee","Origin","Destination"] 
		@chart.each do |consignee, shipment_set|
			csv << [consignee, shipment_set.first.origin.to_s, shipment_set.first.destination.to_s] 
		end
  	end
  end

  def deep_search(keywords)
  	consignees = []
  	shippers = []
  	first_pass = scrape_results('shipper',keywords)
  	first_pass.each do |consignee, shipment|
  		consignees << consignee
  	end
  	puts "About to search for shipments to #{consignees}"
  	second_pass = scrape_results('consignee',consignees)
  	p second_pass
  	second_pass.each_value do |shipment|
  		shippers << shipment.first.shipper
  		puts "adding shipper: #{shipment.first.shipper} to list"
  	end
  	shippers = shippers.uniq
  	chart = scrape_results('shipper',shippers)
  	
  	return chart
  end

 
  def get_page(url)
  	begin
  		page = Nokogiri::HTML(open(url))
  	rescue
  		page = Nokogiri::HTML(open(url))
  	end
  	page
  end
	


  def process_page(search_type,keyword,page)
  	@chart_element = {}
  	doc = get_page("https://portexaminer.com/search.php?search-field-1=#{search_type}&search-term-1=#{keyword}&p=#{page}")
	doc.css("div[class=search-item]").each do |item|
		blurb = item.css('div.blurb').children.text
		excluded_countries = ["China","India","Hong Kong","Singapore","Goose Island","South Korea","Virgin Islands","Asia","Panama"]
		next if excluded_countries.any? { |country| blurb.include?(country)}
		title = item.css('div').css('h2').css('a').attribute('href').text[2..-1]
		company_info = blurb.split("aboard")[0].split("shipped to")
		#puts title	
		location_info = blurb.string_between_markers("aboard","The cargo")
		if location_info == nil
			origin = "N/A"
			date = "N/A"
			destination = "N/A"
		else
			if location_info.string_between_markers("loaded at"," and ") != nil 
				origin = location_info.string_between_markers("loaded at"," and ")
			else
				origin = "None Given"
			end
			date = location_info.string_between_markers(" on ",".")
			destination = location_info.string_between_markers("discharged at"," on ")

		end

		


		repeat = false
		@chart_element["#{keyword}#{@count}"] = Shipment.new(keyword,@count,title.sub!("portexaminer.com",''),company_info[0],company_info[1],origin,destination,date)
		
		@count += 1
	end
	@chart_element
  end


  def scrape_results(search_type,keywords)
  	chart = {}
  	@count = 1
  	@pages = []
  	threads = []
  	chart_mutex = Mutex.new

  	results = keywords.each do |word|
  		puts "searching for #{word}"
  		@count = 1
  		keyword = word.dup
  		keyword.strip!
		doc = get_page("https://portexaminer.com/search.php?search-field-1=#{search_type}&search-term-1=#{keyword}")
		@pages << [keyword,1]
	#	puts "Got first page and page count for #{keyword}"
		#puts doc.css("div[class=search-item]").css("div[class=blurb]")
		#process_page(keyword, doc)
		number_of_pages = doc.css("div[id=search-results]").xpath("//div").xpath("//p")[0]
		number_of_pages = number_of_pages != nil ? number_of_pages.text.split(" ").last.to_i : 0
		if number_of_pages != 0
			(2..number_of_pages).each do |page|
				@pages << [keyword,page]
			end
			puts @pages.last
			
		end
  	end

  	thread_count = 8
  	thread_count.times.map {
  		Thread.new(@pages,chart) do |pages, chart|
  			while page = chart_mutex.synchronize { pages.pop }
  				puts page[0], page[1]
  				chart_element = process_page(search_type,page[0],page[1])
  				chart_mutex.synchronize { chart.merge!(chart_element) }
  			end
  		end
  	}.each(&:join)

	if params[:remove_subsidiaries]
		chart.each do |key, shipment|
			#puts key, shipment.consignee,shipment.shipper
			shipper_first_word = shipment.shipper.split[0]
			consignee_first_word = shipment.consignee.split[0]
			if shipper_first_word.include? consignee_first_word
				chart.delete(key)
				@removed_subsidiaries = true
			end
		end
	end


  	shipments_by_consignees = Hash.new { |hsh, key| hsh[key] = Set.new }
  	chart.each_value do |shipment|
  		shipments_by_consignees[shipment.consignee].add(shipment)
  	end

  shipments_by_consignees
  end


end
class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end
