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
require 'builder'
require "fileutils"
require "json"

# We need a valid API token
API_TOKEN = ENV['MOBICHECKIN_API_TOKEN']

# We need an event id
EVENT_ID = ENV['MOBICHECKIN_EVENT_ID']

NB_GUEST_PER_PAGE = 500

["API_TOKEN", "EVENT_ID"].each do |var_name|
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
  return JSON.parse response.body
end

def fetch_exhibitors
  api_url_connection("/api/v1/events/#{EVENT_ID}/exhibitors.json?&auth_token=#{API_TOKEN}")
end

def fetch_exhibitor_connections(exhibitor_id)
  api_url_connection("/api/v1/events/#{EVENT_ID}/exhibitors/#{exhibitor_id}/connections.json?&auth_token=#{API_TOKEN}")
end

def fetch_guests(page_number)
  puts "Querying API for guests"
  api_url_connection("/api/v1/events/#{EVENT_ID}/guests.json?page=#{page_number}&auth_token=#{API_TOKEN}&guest_metadata=true")
end

def fetch_event
  api_url_connection("/api/v1/events/#{EVENT_ID}.json?auth_token=#{API_TOKEN}")
end

def get_number_of_guest
  fetch_event["guest_count"]
end

def build_guests_hash
  @guests = {}
  
  expected_nb_guests = get_number_of_guest.to_i

  array_divmod = expected_nb_guests.divmod NB_GUEST_PER_PAGE
  nb_pages = array_divmod.first
  nb_pages += 1 if array_divmod.last > 0
  for page_number in 1..nb_pages
    doc = fetch_guests(page_number.to_s)
    doc.each do |guest|
      @guests[guest["uid"]] = guest
    end
  end
end

def get_exhibitors
  exhibitors = {}
  exhibitors_hash = fetch_exhibitors
  exhibitors_hash.each do |ex|
    exhibitors[ex['_id']] = { :name => ex["name"], :meta_data => ex["meta_data"], :email => ex["email"] }
  end
  exhibitors
end
INTERESTING_MEDATA = ["WHICH I THE INTEREST?", "WHAT'S IS IT", "STATUS", "COST"]
def metadata_from_guest(guest)
  metadata = {}
  
  guest["guest_metadata"].each do |gm|
    key  = gm['name']
    next unless INTERESTING_MEDATA.include? key
    metadata[key] = gm["value"]
  end
  metadata
end

def main
  build_guests_hash
  unless File.directory? EXHIBITORS_CONNECTIONS_FOLDER
    puts "Creating exhibitors connections folder #{EXHIBITORS_CONNECTIONS_FOLDER}..."
    FileUtils.mkdir_p EXHIBITORS_CONNECTIONS_FOLDER
  end
  file_name = File.join(EXHIBITORS_CONNECTIONS_FOLDER, "export.csv")
  file = File.open(file_name, 'wb') do |f|
    get_exhibitors.each do |exhibitor_id, payload| do
      name = payload["name"]
      email = payload["email"]
      fetch_exhibitor_connections(exhibitor_id).each do |connection|
        line = []
        uid = connection["guest_uid"]
        line << uid
        guest = @guests[uid]
        metadata = metadata_from_guest guest
        INTERESTING_MEDATA.each do |mdkey|
          line << metadata[mdkey]
        end
        f.write line
      end
    end
  end
  file.close
end

main