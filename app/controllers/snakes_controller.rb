require 'open-uri'
class SnakesController < ApplicationController

  def index
	path = request.original_fullpath
	path.slice!("/port_examiner")
	ip = open('http://whatismyip.akamai.com').read
	response = open("https://portexaminer.com#{path}").read.gsub("/search.php","/collator/port_examiner/search.php").gsub("portexaminer.com","#{ip}/collator/port_examiner")
	render :inline => response
	
  end

end
