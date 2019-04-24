class Search < ActiveRecord::Base
	has_many :search_keywords
	has_many :keywords, through: :search_keywords
	#attr_accessor :search_id, :shipment_id
end
