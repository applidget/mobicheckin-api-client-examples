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
require "fileutils"

# We need a valid API token
API_TOKEN = ENV['MOBICHECKIN_API_TOKEN']
HOST_SITE = ENV['HOST_SITE']
CC_EMAIL = ENV['CC_EMAIL']
# We need an event id
EVENT_ID = ENV['MOBICHECKIN_EVENT_ID']

NB_GUEST_PER_PAGE = 500

["API_TOKEN", "EVENT_ID", "CC_EMAIL", "HOST_SITE"].each do |var_name|
  unless Kernel.const_get var_name
    puts "Could not find #{var_name} in your environment"
  end
end
  
EXHIBITORS_CONNECTIONS_FOLDER = File.join(File.join(File.expand_path(File.dirname(__FILE__)), "exhibitors_connections"), EVENT_ID)

def api_url_connection(url)
  request_uri = url
  
  http_connection = Net::HTTP.new("app.mobicheckin.com", 443)
  http_connection.use_ssl = true
  response = nil
  http_connection.start do |http|
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
  puts "Querying API for guests"
  api_url_connection("/api/v1/events/#{EVENT_ID}/guests.xml?page=#{page_number}&auth_token=#{API_TOKEN}")
end

def get_xml_event
  api_url_connection("/api/v1/events/#{EVENT_ID}.xml?auth_token=#{API_TOKEN}")
end

def get_number_of_guest
  REXML::XPath.each(get_xml_event, '//event').each do |event|
    return event.elements["guest-count"].text
  end
end

def build_guests_hash
  @guest = {}
  
  expected_nb_guests = get_number_of_guest.to_i
  array_divmod = expected_nb_guests.divmod NB_GUEST_PER_PAGE
  nb_pages = array_divmod.first
  nb_pages =+ 1 if array_divmod.last > 0
  
  for page_number in 1..nb_pages
    REXML::XPath.each(get_xml_guests(page_number.to_s), '//guest').each do |guest|
      @guest[guest.elements["uid"].text] = guest.elements
    end
  end
end

def get_exhibitors
  exhibitors = {}
  REXML::XPath.each(get_xml_exhibitors, '//exhibitor').each do |exhibitor|
    exhibitors[exhibitor.elements["_id"].text] = { :name => exhibitor.elements["name"].text, :meta_data => exhibitor.elements["meta-data"].text  }
  end
  exhibitors
end

def get_candidate_comments(xml_node, comments_xml)
  REXML::XPath.each(comments_xml, 'comment').each do |comment|
    xml_node.RecruiterComment comment.elements["content"].text unless comment == ""
  end
end

def exhibitor_xml(xml_node, exhibitor_id, recruiter_email)
  REXML::XPath.each(get_xml_exhibitor_connections(exhibitor_id), '//connection').each do |connection|
    xml_node.Candidate do |candidate|
      uid = connection.elements["guest-uid"].text
      if @guest[uid]
        candidate.Email @guest[uid]["email"].text
        candidate.RecruiterEmail recruiter_email
        candidate.CCEmail CC_EMAIL
        candidate.RecruiterComments do |comments|
          get_candidate_comments(comments, connection.elements["comments"])
        end
      end
    end
  end
end

def main
  build_guests_hash

  unless File.directory? EXHIBITORS_CONNECTIONS_FOLDER
    puts "Creating exhibitors connections folder #{EXHIBITORS_CONNECTIONS_FOLDER}..."
    FileUtils.mkdir_p EXHIBITORS_CONNECTIONS_FOLDER
  end
  
  file_name = File.join(EXHIBITORS_CONNECTIONS_FOLDER, "export.xml")
  File.open(file_name, 'wb') do |f|
    xml = Builder::XmlMarkup.new( :indent => 2 )
    xml.instruct! :xml, :encoding => "UTF-8"
    xml.CareerFare do |career_fare|
      career_fare.HostSite HOST_SITE
      get_exhibitors.each do |exhibitor_id, payload|
        recruiter_email = payload[:meta_data] #In this usecase we have put a recruiter email
        exhibitor_xml(career_fare, exhibitor_id, recruiter_email)
      end
    end
    f.write xml.target!
  end
end

main