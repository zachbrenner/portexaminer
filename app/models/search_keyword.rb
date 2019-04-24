class SearchKeyword < ActiveRecord::Base
	belongs_to :search
	belongs_to :keyword
end