require 'open-uri'
require 'thread'
require 'csv'
require 'json'
class SearchController < ApplicationController
  include SearchHelper
	Shipments = Struct.new(:keyword, :count,:url, :shipper, :consignee, :origin, :destination, :date)
  def index
  end
/ if need to save something, do this to save performance
  product = Product.first
  product.save if product.changed?
/

  def show
    logger.info "in SearchController/show"
    @search_status = ''
    @used_keywords = []
    @keyword_ids = []
    @status_code = 0
    search = Search.find(params[:search_id])
    @shipment_records = get_shipments_from_search(search.id)
    @csv = Time.now.usec.to_s

    if search.done == true
      @search_status = "Search in Progress"
      @status_code = 1
      @csv = Time.now.usec.to_s
      #generate_csv(search, @csv)
      p @csv
    end

  end
 
  def expand

    @keywords = [params[:keywords]]
    logger.info "Expand keywords: #{@keywords}"
    shipper_search = Search.create(done:false)
    SearchWorker.new.perform(shipper_search.id,"consignee",false,@keywords,false)
    
    shippers = get_shipments_from_search(shipper_search.id).map(&:shipper)
    logger.info "Found these shippers #{shippers}"
    shippers.delete(params[:shipper])

    consignee_search = Search.create(done:false)
    SearchWorker.new.perform(consignee_search.id,"shipper",false,shippers,false)
    
    
    @shipment_records_json = get_shipments_from_search(consignee_search.id).to_json
    render :json => @shipment_records_json

  end

  def remove_existing_results(search_id, expand_search_id)
    existing_results = Shipment.where(qid:search_id)
    expand_results = Shipment.where(qid:expand_search_id)
    new_result_id = []
    expand_results.each do |shipment|

    end
    puts "******** remove_existing results ******** existing, expand and new lengths: #{existing_results.length} #{expand_results.length} #{new_results.length}"
    expand_results.each do |record|
      puts record
      p record
    end
  end

  def search
  	tn = Time.now
    puts "keywords #{params[:keywords]}"
    p params[:keywords]
  	@keywords = params[:keywords].split(",").reverse
  	search_type = params[:search_type]
  	remove_subsidiaries = params[:remove_subsidiaries]
    puts params
	  @remove_subs_was_checked = false
	  @removed_subsidiaries = false
	  if remove_subsidiaries
		  @remove_subs_was_checked = true
	  else
		  @remove_subs_was_checked = false
	  end
	  logger.info "Searching for #{@keywords}"
    
    @chart = {}
  	@used_keywords = []
    @search = Search.create(done:false)

    deep_search = params[:deep_search] ? true : false

    job_id = SearchWorker.perform_async(@search.id,search_type,remove_subsidiaries,@keywords,deep_search)


    sleep 2
  	@t = Time.now - tn
  
    if params[:expand] == 'true'
      redirect_to "/collator/expand/#{@search.id}"
    else
      redirect_to "/collator/search/#{@search.id}"
    end
    
  end	



  def generate_csv(search, file)
    p file
    CSV.open("#{Rails.root}/public/#{file}","wb") do |csv|
		  csv << ["Cosignee","Origin","Destination"] 
		  search.shipments.each do |shipment|
			 csv << [shipment.consignee.to_s, shipment.origin.to_s, shipment.destination.to_s] 
		  end
  	end
    return file
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
		@chart_element["#{keyword}#{@count}"] = Shipments.new(keyword,@count,title.sub!("portexaminer.com",''),company_info[0],company_info[1],origin,destination,date)
		
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
