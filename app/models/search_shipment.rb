class SearchShipment < ActiveRecord::Base
	belongs_to :search
	belongs_to :shipment
end