class Keyword < ActiveRecord::Base
	has_many :shipments
	has_many :search_keywords
	has_many :searches, through: :search_keywords
end
