require 'open-uri'
class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  def hello
  	doc = Nokogiri::HTML(open("http://portexaminer.com/search.php?search-field-1=shipper&search-term-1=vise"))
  	@search_items = doc.css("div[class='search-item']")

  end
end
