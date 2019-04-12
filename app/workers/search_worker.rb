#methods need to be moved around - insertion into the database must be made into it's own method to accomidate deep search

require 'open-uri'
require 'thread'
class SearchWorker
  include Sidekiq::Worker
  Shipments = Struct.new(:keyword, :count,:url, :shipper, :consignee, :origin, :destination, :date)

  def perform(search_id,search_type,remove_subs,keywords,deep_search)
  	logger.info "worker started"
    logger.info "search id: #{search_id}"
  	@search = Search.find(search_id)
    @job_id = self.jid
  	logger.info "In worker"
    insert_in_db(scrape_results(search_type,remove_subs,keywords))

  end
  
  def get_page(url)
  	begin
  		page = Nokogiri::HTML(open(url))
  	rescue
  		logger.info "page load failed, rescuing"
  		page = Nokogiri::HTML(open(url))
  	end
  	page
  end
	
  def deep_search(remove_subs,keywords)
    puts "in Deep search method"
    consignees = []
    shippers = []
    logger.info "Starting first pass - searching for consignees of shippers"
    first_pass = scrape_results('shipper',remove_subs,keywords)
    logger.info "Finished first pass"
    logger.info "building consinee list"
    first_pass.each do |consignee, shipment|
      consignees << consignee
    end
    logger.info "Will begin search for First pass results which are #{consignees}"
    puts "About to search for shipments to #{consignees}"
    second_pass = scrape_results('consignee',remove_subs,consignees)
    logger.info "Finished second pass"
    second_pass.each_value do |shipment|
      shippers << shipment.first.shipper
      puts "adding shipper: #{shipment.first.shipper} to list"
    end
    shippers = shippers.uniq
    chart = scrape_results('shipper',remove_subs,shippers)
    
    return chart
  end

  def process_page(search_type,keyword,page)
  	@chart_element = {}
  	doc = get_page("https://portexaminer.com/search.php?search-field-1=#{search_type}&search-term-1=#{keyword}&p=#{page}")
    return Shipments.new if doc == nil
    logger.info "got page #{page} for #{keyword}"
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


  def scrape_results(search_type,remove_subs,keywords)
  	chart = {}
  	@count = 1
  	@pages = []
  	threads = []
  	chart_mutex = Mutex.new

  	results = keywords.each do |word|
  		puts "searching for #{search_type} #{word}"
  		@count = 1
  		keyword = word.dup
  		keyword.strip!
      url = "https://portexaminer.com/search.php?search-field-1=#{search_type}&search-term-1=#{keyword}"
      doc = get_page(url)
		  @pages << [keyword,1]
	#	puts "Got first page and page  for #{keyword}"
		#puts doc.css("div[class=search-item]").css("div[class=blurb]")
		#process_page(keyword, doc)
		  number_of_pages = doc.css("div[id=search-results]").xpath("//div").xpath("//p")[0]
		  number_of_pages = number_of_pages != nil ? number_of_pages.text.split(" ").last.to_i : 0
		  if number_of_pages != 0
			 (2..number_of_pages).each do |page|
			 	 @pages << [keyword,page]
			 end
		  end
  	end

  	logger.info "Starting to get pages"
  	thread_count = 8
  	thread_count.times.map {
  		Thread.new(@pages,chart) do |pages, chart|
  			while page = chart_mutex.synchronize { pages.pop }
  				chart_element = process_page(search_type,page[0],page[1])
  				chart_mutex.synchronize { chart.merge!(chart_element) }
  			end
  		end
  	}.each(&:join)
  	logger.info "fined getting pages"
	if remove_subs
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

  def insert_in_db(shipments_by_consignees)
    
    shipments_by_consignees.each do |key, shipment_set|
      t = Time.now
      shipment = shipment_set.first
      puts Time.now - t
      p @search
      shipment_record = @search.shipments.build(url:shipment.url, shipper:shipment.shipper, consignee:shipment.consignee, origin:shipment.origin, destination:shipment.destination, date:shipment.date)
      puts "AAAAAAAAAAAAAAAA"
      puts shipment_record.valid?
      if shipment_record.valid?
        puts "saving shipment record"
        p shipment_record
        shipment_record.save
        p shipment_record
        puts "search:"
        p Search.find(@search.id).shipments

      else
        puts "already in db, making a reference to this search"
        existing_record = Shipment.find_by_consignee(shipment.consignee)
        puts "updating join table"
        p SearchShipment.create(search_id:@search.id, shipment_id:existing_record.id)
            
      end
    end
    Search.find(@search.id).update(done:true)
  end

end
