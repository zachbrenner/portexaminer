module SearchHelper
	def build_pagination_array(keyword,doc)
		pages = []
		pages << [keyword,1]
		number_of_pages = doc.css("div[id=search-results]").xpath("//div").xpath("//p")[0]
		number_of_pages = number_of_pages != nil ? number_of_pages.text.split(" ").last.to_i : 0
      	if number_of_pages != 0
			(2..number_of_pages).each do |page|
         		pages << [keyword,page]
			end
		end
		return pages
	end

	def remove_whitespace(arr)
		arr.collect!(&:strip)
	end

	def get_shipments_from_search(search_id)
		Search.find(search_id).keywords.map(&:shipments).flatten
	end
end
