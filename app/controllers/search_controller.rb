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
  	@chart = scrape_results(@keywords)
  	@t = Time.now - tn
	@file_name = (Time.new.strftime("%I:%M%p %m-%d-%Y-") + rand(1000..9999).to_s + ".csv")
	generate_csv(@file_name)
  end	

  def generate_csv(file_name)
	CSV.open("#{Rails.root}/public/#{file_name}","wb") do |csv|
		csv << ["Cosignee","Origin","Destination"] 
		@chart.each do |consignee, shipment_set|
			p shipment_set.first.origin, shipment_set.first.destination
			csv << [consignee, shipment_set.first.origin.to_s, shipment_set.first.destination.to_s] 
		end
  	end
  end

  def get_page(url)
  	begin
  		page = Nokogiri::HTML(open(url))
  	rescue
  		page = Nokogiri::HTML(open(url))
  	end
  	page
  end
	


  def process_page(keyword,page)
  	@chart_element = {}
  	puts "trying to fet #{keyword} #{page}"
  	doc = get_page("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}&p=#{page}")
	puts "Got #{keyword} #{page}, parsing"
	doc.css("div[class=search-item]").each do |item|
		blurb = item.css('div.blurb').children.text
		#next if blurb.any? { |country| ["China","India","Hong Kong","Singapore","Goose Island","South Korea","Virgin Islands"].include?(country) }
		excluded_countries = ["China","India","Hong Kong","Singapore","Goose Island","South Korea","Virgin Islands","Asia","Panama"]
		next if excluded_countries.any? { |country| blurb.include?(country)}
		title = item.css("div[class=title]").children.children.attribute('href').text[2..-1]

		company_info = blurb.split("aboard")[0].split("shipped to")
		
		location_info = blurb.string_between_markers("aboard","The cargo")
		p location_info
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
		#@chart.each do |key, value|
		#	if company_info[1] == value[1]
		#		repeat = true
		#		break
		#	end
		#end
		#next if repeat == true
		@chart_element["#{keyword}#{@count}"] = Shipment.new(keyword,@count,title.sub!("portexaminer.com",''),company_info[0],company_info[1],origin,destination,date)
		
		#p title = item.css("div[class=title]")
		#p title.attribute("div")
		@count += 1
		#puts item
		end
		puts "parsing #{keyword} #{page} done"
		@chart_element
  end


  def scrape_results(keywords)
  	chart = {}
  	@count = 1
  	@pages = []
  	threads = []
  	chart_mutex = Mutex.new

  	results = keywords.each do |keyword|
  		@count = 1
  		keyword.strip!
		doc = get_page("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}")
		@pages << [keyword,1]
		puts "Got first page and page count for #{keyword}"
		#puts doc.css("div[class=search-item]").css("div[class=blurb]")
		#process_page(keyword, doc)
		if doc.css("div.pager").xpath('p')[0] != nil
			number_of_pages = doc.css("div.pager").xpath('p')[0].text.split(" ")[3].to_i
			
			(2..number_of_pages).each do |page|
				puts "Inserting #{keyword} page #{page} into list to scrap"
				#page_doc = Nokogiri::HTML(open("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}&p=#{page}"))
				@pages << [keyword,page]
				#process_page(keyword,page_doc)
			end
			
		end
  	end
	
  	#@pages.each do |page|
  	#	threads << Thread.new(page,chart) do |page, chart|
  	#		chart_element = process_page(page[0],page[1])
  	#		chart_mutex.synchronize {chart.merge!(chart_element)}
  	#	end
  	#end
  	#threads.each(&:join)

  	thread_count = 8
  	thread_count.times.map {
  		Thread.new(@pages,chart) do |pages, chart|
  			while page = chart_mutex.synchronize { pages.pop }
  				chart_element = process_page(page[0],page[1])
  				chart_mutex.synchronize { chart.merge!(chart_element) }
  			end
  		end
  	}.each(&:join)

  	shipments_by_consignees = Hash.new { |hsh, key| hsh[key] = Set.new }
  	chart.each_value do |shipment|
  		shipments_by_consignees[shipment.consignee].add(shipment)
  	end
  	#p shipments_by_consignees
  	#puts consignees.length

 	#chart.each_with_index do |n, chart|
 	#	puts n,chart
 	#end
  shipments_by_consignees
  end
end
class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end
