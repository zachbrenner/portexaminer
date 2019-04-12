class Shipment < ActiveRecord::Base
	has_many :search_shipments
	has_many :searches, :through => :search_shipments
	validates :consignee, uniqueness: true
	#attr_accessor :search_id, :shipment_id

end
