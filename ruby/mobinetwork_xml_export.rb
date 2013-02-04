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

EXHIBITORS_CONNECTIONS_FOLDER = File.join(File.join(File.expand_path(File.dirname(__FILE__)), "exhibitors_connections"), EVENT_ID)

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

def get_exhibitors_ids
  exhibitors_ids = []
  REXML::XPath.each(get_xml_exhibitors, '//exhibitor').each do |exhibitor|
    exhibitors_ids << exhibitor.elements["_id"].text
  end
  exhibitors_ids
end

def get_candidate_comments(comments_xml)
  comments = ""
  REXML::XPath.each(comments_xml, 'comment').each do |comment|
    if comments == ""
      comments = comment.elements["content"].text
    else
      comments += ";" + comment.elements["content"].text
    end
  end
  comments
end

def build_exhibitor_xml(exhibitor_id)
  xml = Builder::XmlMarkup.new( :indent => 2 )
  xml.CareerFare do |career_fare|
    career_fare.HostSite
    REXML::XPath.each(get_xml_exhibitor_connections(exhibitor_id), '//connection').each do |connection|
      xml.Candidate do |candidate|
        if guest_with_uid(connection.elements["guest-uid"].text)
          guest = guest_with_uid(connection.elements["guest-uid"].text)
          candidate.Email guest.elements["email"].text
          candidate.RecruiterEmail
          candidate.CCEmail
          candidate.RecruiterComments get_candidate_comments(connection.elements["comments"])
        end
      end
    end
  end
end

def main 
  unless File.directory? EXHIBITORS_CONNECTIONS_FOLDER
    puts "Creating exhibitors connections folder #{EXHIBITORS_CONNECTIONS_FOLDER}..."
    FileUtils.mkdir_p EXHIBITORS_CONNECTIONS_FOLDER
  end
  
  get_exhibitors_ids.each do |exhibitor_id|
    File.open(File.join(EXHIBITORS_CONNECTIONS_FOLDER, File.join("#{exhibitor_id}.txt")), 'wb') do |f|
      f.write build_exhibitor_xml(exhibitor_id)
    end
  end
end

main