#!/usr/bin/ruby
#
# API Reference: https://app.mobicheckin.com/api
#
# Usage: $ MOBICHECKIN_API_TOKEN=XXXXXX MOBICHECKIN_EVENT_ID=0000000 ./mobinetwork_xml_export.rb
#
# Author: Ahrry Gopal (@ahrry)
# Company: Applidget

require 'builder'

def product_xml
  
  # API_TOKEN = ENV['MOBICHECKIN_API_TOKEN']
  # EVENT_ID = ENV['MOBICHECKIN_EVENT_ID']
  # 
  # uri = "http://localhost:3000/api/v1/events/#{EVENT_ID}/guests.xml?page=1&auth_token=#{API_TOKEN}"
    
  xml = Builder::XmlMarkup.new( :indent => 2 )
  xml.instruct! :xml, :encoding => "ASCII"
  
  xml.CareerFare do |carreer_fare|
    carreer_fare.HostSite "SE"
    carreer_fare.Candidate do |candidate|
      candidate.Email "rbolibo@yahoo.co.uk"
      candidate.RecruiterEmail "nathalie.estrabol@steria.com"
    end
  end
  
end

puts product_xml