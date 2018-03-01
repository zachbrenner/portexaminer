require 'open-uri'
class SearchController < ApplicationController
  def index
  	
  end
  def search
  	@keywords = params[:keywords].split(",")
  	scrape_results(@keywords)

  end	

  def process_page(keyword,doc)

	doc.css("div[class=search-item]").each do |item|
		blurb = item.css('div.blurb').children.text
		#next if blurb.any? { |country| ["China","India","Hong Kong","Singapore","Goose Island","South Korea","Virgin Islands"].include?(country) }
		excluded_countries = ["China","India","Hong Kong","Singapore","Goose Island","South Korea","Virgin Islands"]
		next if excluded_countries.any? { |country| blurb.include?(country)}
		title = item.css("div[class=title]").children.children.attribute('href').text[2..-1]
		
		p company_info = blurb.split("aboard")[0].split("shipped to")
		location_info = blurb.split("loaded at")[1].split(".")[0]
		origin = location_info.split(" and ")[0]
		date = location_info.split("on")[location_info.split("on").length-1].strip
		destination = location_info.string_between_markers("discharged at"," on ").strip
		repeat = false
		@chart.each do |key, value|
			if company_info[1] == value[1]
				repeat = true
				puts "repeat"
				break
			end
		end
		next if repeat == true

		@chart[[@count,keyword,"http://" + title]] = company_info + [origin,destination,date]
		#p title = item.css("div[class=title]")
		#p title.attribute("div")
		@count += 1
		#puts item
		end
  end


  def scrape_results(keywords)
  	@chart = {}
  	@count = 1

  	results = keywords.each do |keyword|
  		@count = 1
  		keyword.strip!
		doc = Nokogiri::HTML(open("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}"))
		puts "Processing #{keyword}"
		#puts doc.css("div[class=search-item]").css("div[class=blurb]")
		process_page(keyword, doc)
		if doc.css("div.pager").xpath('p')[0] != nil
			number_of_pages = doc.css("div.pager").xpath('p')[0].text.split(" ")[3].to_i
			(2..number_of_pages).each do |page|
				puts "Processing #{keyword} page #{page}"
				page_doc = Nokogiri::HTML(open("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}&p=#{page}"))
				process_page(keyword,page_doc)
			end
		end
  	end
  #	chart
  end
end
class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end
