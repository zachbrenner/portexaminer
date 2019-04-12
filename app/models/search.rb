class Search < ActiveRecord::Base
	has_many :search_shipments
	has_many :shipments, :through => :search_shipments
	#attr_accessor :search_id, :shipment_id
end
