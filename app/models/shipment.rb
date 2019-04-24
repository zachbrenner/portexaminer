class Shipment < ActiveRecord::Base
	belongs_to :keyword
	validates :consignee, uniqueness: true
	#attr_accessor :search_id, :shipment_id

end
