#methods need to be moved around - insertion into the database must be made into it's own method to accomidate deep search

require 'open-uri'
require 'thread'
class SearchWorker
  include Sidekiq::Worker
  include SearchHelper 
  Shipments = Struct.new(:keyword, :count,:url, :shipper, :consignee, :origin, :destination, :date)

  def perform(search_id,search_type,remove_subs,keywords,deep_search)
  	logger.info "worker started"
    logger.info "search id: #{search_id}"
  	@search = Search.find(search_id)
    @job_id = self.jid
    p keywords
    keywords = remove_whitespace(keywords)
    process_keywords(keywords,search_id, search_type,remove_subs)
    @search.update(done:true)

    p keywords


  end

  def process_keywords(keywords,search_id, search_type, remove_subs)
    logger.info "In process_keywords"
    search = Search.find(search_id)
    keywords.each do |keyword|
      logger.info "keyword has been searched: #{Keyword.where(keyword:keyword,search_type:search_type).exists?} "
      if Keyword.where(keyword:keyword,search_type:search_type).exists?
        keyword_record = Keyword.where(keyword:keyword,search_type:search_type).first
        logger.info "Keyword has already been searched: Associating keyword: #{keyword} with search id: #{search_id}"
        SearchKeyword.create(keyword_id:keyword_record.id,search_id:search_id)
      else
        logger.info "Creating new keyword record: #{keyword} #{search_type}"
        new_keyword_record = search.keywords.create(keyword:keyword, search_type:search_type)
        logger.info "created keyword record: #{Keyword.find_by_id(new_keyword_record.id)}"
        logger.info "running keyword #{keyword}"
        keyword_shipments = build_keyword_results(keyword,search_type,remove_subs)
        logger.info "Got keyword data, adding to database"
        add_shipments_to_db(keyword_shipments,new_keyword_record.id)
      end
    end
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
    @count = 1
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

 def build_keyword_results(keyword,search_type,remove_subs)
    chart = {}
    threads = []
    chart_mutex = Mutex.new
    puts "searching for #{search_type} #{keyword}"
    url = "https://portexaminer.com/search.php?search-field-1=#{search_type}&search-term-1=#{keyword}"
    doc = get_page(url)
    p keyword
    @pages = build_pagination_array(keyword,doc)
    p @pages
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
      logger.info "#{shipment}"
    end

  shipments_by_consignees

  end

 

  def add_shipments_to_db(shipments_by_consignees, keyword_id)
    logger.info "In add_shipments_to_db"
    shipments_by_consignees.each do |key, shipment_set|
      shipment = shipment_set.first

      keyword = Keyword.find(keyword_id)

      logger.info "assigning shipment to keyword: #{keyword.keyword}"
      shipment_record = keyword.shipments.build(url:shipment.url, shipper:shipment.shipper, consignee:shipment.consignee, origin:shipment.origin, destination:shipment.destination, date:shipment.date)
      shipment_record.save
     / if nil
      puts "AAAAAAAAAAAAAAAA"
      puts shipment_record.valid?
      if shipment_record.valid?
        puts "saving shipment record"
        p shipment_record
        shipment_record.save
        p shipment_record
        puts "search:"
        p Search.find(@search.id).shipments
      end
    end/
    end
  end

end

