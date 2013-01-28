#!/usr/bin/ruby
#
# API Reference: https://app.mobicheckin.com/api
#
# Usage: $ MOBICHECKIN_API_TOKEN=XXXXXX MOBICHECKIN_EVENT_ID=0000000 ./mobinetwork_xml_export.rb
#
# Author: Ahrry Gopal (@ahrry)
# Company: Applidget

require 'cgi'
require 'net/https'
require "rexml/document"
require 'builder'

def api_token
  api_token = "4kLsFwQTP35pkNoMDLer" # ENV['MOBICHECKIN_API_TOKEN']
end

def event_id
  event_id = "4fbc9e7a283d4f45bd000007" # ENV['MOBICHECKIN_EVENT_ID']
end

def api_url_connection(url)
  request_uri = url
  
  http = Net::HTTP.new("app.mobicheckin.com", 443)
  http.use_ssl = true
  response = nil
  http.start do |http|
    req = Net::HTTP::Get.new request_uri
    response = http.request req
    if response.code != "200"
      puts "Got an error #{response.code} from the API. Please check your API token or event id."
      abort
    end
  end
  doc = REXML::Document.new(response.body)
  if doc.root.elements.count == 0
    puts "Your event doesn't have any guest yet."
    exit
  else
    return doc
  end
end

def get_xml_exhibitors
  api_url_connection("/api/v1//events/#{event_id}/exhibitors.xml?&auth_token=#{api_token}")
end

def get_xml_exhibitor_connections(exhibitor_id)
  api_url_connection("/api/v1//events/#{event_id}/exhibitors/#{exhibitor_id}/connections.xml?&auth_token=#{api_token}")
end

def candidates
  exhibitor_ids = []
  get_xml_exhibitors.elements.each('exhibitors/exhibitor/_id') do |ele|
    exhibitor_ids << ele.text
  end
  
  exhibitor_ids.each do |exhibitor_id|
    puts get_xml_exhibitor_connections(exhibitor_id)
  end
end

def product_xml
  
  xml = Builder::XmlMarkup.new( :indent => 2 )
  xml.instruct! :xml, :encoding => "UTF-8"
  
  xml.CareerFare do |carreer_fare|
    get_xml_exhibitors.elements.each('exhibitors/exhibitor/name') do |exhibitor_name|
      carreer_fare.HostSite exhibitor_name.text
    end
  end
  
end

puts product_xml
