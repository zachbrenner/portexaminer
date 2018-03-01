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
		#next if blurb.include?("China") or blurb.include?("India")
		title = item.css("div[class=title]").children.children.attribute('href').text[2..-1]
		@chart[[@count,keyword,"http://" + title]] = blurb
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
