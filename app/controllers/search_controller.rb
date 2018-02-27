require 'open-uri'
class SearchController < ApplicationController
  def index
  	
  end
  def search
  	@keywords = params[:keywords].split(",")
  	@chart = {}
  	@count = 1
  	results = @keywords.each do |keyword|
  		@count = 1
		doc = Nokogiri::HTML(open("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=#{keyword}"))

		#puts doc.css("div[class=search-item]").css("div[class=blurb]")
		doc.css("div[class=search-item]").each do |item|
			blurb = item.css('div.blurb').children.text
			next if blurb.include?("China") or blurb.include?("India")
			title = item.css("div[class=title]").children.children.attribute('href').text[2..-1]
			@chart[[@count,keyword,"http://" + title]] = blurb
			#p title = item.css("div[class=title]")
			#p title.attribute("div")
			@count += 1
		#puts item
		end
  	end

  end
end
