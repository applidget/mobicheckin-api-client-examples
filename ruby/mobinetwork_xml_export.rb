#!/usr/bin/env ruby -w
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

# We need a valid API token
API_TOKEN = ENV['MOBICHECKIN_API_TOKEN']
unless API_TOKEN
  puts "Could not find MOBICHECKIN_API_TOKEN in your environment"
  abort
end

# We need an event id
EVENT_ID = ENV['MOBICHECKIN_EVENT_ID']
unless EVENT_ID
  puts "Could not find MOBICHECKIN_EVENT_ID in your environment"
  abort
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
  return doc
end

def get_xml_exhibitors
  api_url_connection("/api/v1/events/#{EVENT_ID}/exhibitors.xml?&auth_token=#{API_TOKEN}")
end

def get_xml_exhibitor_connections(exhibitor_id)
  api_url_connection("/api/v1/events/#{EVENT_ID}/exhibitors/#{exhibitor_id}/connections.xml?&auth_token=#{API_TOKEN}")
end

def get_xml_guests(page_number)
  api_url_connection("/api/v1/events/#{EVENT_ID}/guests.xml?page=#{page_number}&auth_token=#{API_TOKEN}")
end

def guest_with_uid(uid)
  page_number = 1
  while get_xml_guests(page_number.to_s)
    REXML::XPath.each(get_xml_guests(page_number.to_s), '//guest').each do |guest|
      if guest.elements["uid"].text == uid
        return guest
      end
    end
    page_number += 1
  end
end

def product_xml
  xml = Builder::XmlMarkup.new( :indent => 2 )
  xml.instruct! :xml, :encoding => "UTF-8"
  
  xml.CareerFare do |carreer_fare|
    
    REXML::XPath.each(get_xml_exhibitors, '//exhibitor').each do |exhibitor_elements|
      xml.Exhibitor do |exhibitor|
        exhibitor.name exhibitor_elements.elements["name"].text
        
        REXML::XPath.each(get_xml_exhibitor_connections(exhibitor_elements.elements["_id"].text), '//connection').each do |connection|
          if connection
            xml.Candidate do |candidate|
              if guest_with_uid(connection.elements["guest-uid"].text)
                guest = guest_with_uid(connection.elements["guest-uid"].text)
                candidate.email guest.elements["email"].text
              end
              
              REXML::XPath.each(connection.elements["comments"], '//comment').each do |comment|
                if comment
                  xml.RecruiterComments do |recruiter_comments|
                    recruiter_comments.comment comment.elements["content"].text
                  end
                end
              end
              
            end
          end
        end
        
      end
    end
    
  end
end

puts product_xml