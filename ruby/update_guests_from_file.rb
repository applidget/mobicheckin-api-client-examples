#!/usr/bin/ruby
#
# Script which updates (PUT) guests of a specific event with their metadata
# INPUT file.
#
# Input file format: one guest per line, two columns separated with atab (\t).
# {{uid}}\t<guest-metadata type="array">{{stuff}}</guest-metadata>\r
# {{uid}}\t<guest-metadata type="array">{{stuff}}</guest-metadata>\r
# {{uid}}\t<guest-metadata type="array">{{stuff}}</guest-metadata>\r
#
# API Reference: https://app.mobicheckin.com/api
#
# Usage: $ MOBICHECKIN_API_TOKEN=XXXXXX \
#          MOBICHECKIN_EVENT_ID=0000000 \
#          ./update_guests_from_file.rb /path/to/file/csv
#
# Author: Sebastien Saunier (@ssaunier)
# Company: Applidget, editor of MobiCheckin (http://www.mobicheckin.com)
# License: MIT

require 'cgi'
require 'net/https'
require "rexml/document"

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

# File format: on each line, we have
# {{uid}}\t{{xml}}
# with the {{xml}} containing an array of metadata
def read_file(path, line_separator = "\r")
  guests = []
  File.open(path, "r").each(line_separator) do |line|
    guests << line.split("\t", 2)
  end
  guests
end

def create_http
  http = Net::HTTP.new("app.mobicheckin.com", 443)
  http.use_ssl = true
  http.ca_path = '/etc/ssl/certs'
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.verify_depth = 5
  http
end

def guest_uid_map
  map = Hash.new
  i = 0
  while true do
    i += 1
    http = create_http
    response = nil
    http.start do |address|
      req = Net::HTTP::Get.new "/api/v1/events/#{EVENT_ID}/guests.xml?page=#{i}&auth_token=#{API_TOKEN}"
      response = address.request req
      if response.code != "200"
        puts "Got an error #{response.code} from the API. Please check your API token or event id."
        abort
      end
    end

    doc = REXML::Document.new(response.body)
    if doc.root.elements.count == 0
      break
    else
      puts "Found #{doc.root.elements.count} more guests..."
    end

    REXML::XPath.each(doc, '//guest').each do |guest|
      uid = guest.elements["uid"].text
      id = guest.elements["_id"].text
      map[uid] = id
    end
  end
  map
end

def update_guest(id, metadata)
  return if metadata.nil? || metadata.strip.size == 0
  http = create_http
  http.start do |address|
    req = Net::HTTP::Put.new "/api/v1/events/#{EVENT_ID}/guests/#{id}.xml?auth_token=#{API_TOKEN}"
    req["Content-Type"] = "application/xml"
    req.body = "<guest>#{metadata}</guest>"
    response = address.request req
    puts "Updating guest #{id}..."
    if response.code != "200"
      puts "Got an error #{response.code} from the API whie updating guest #{id}"
    end
  end
end

def main
  file = ARGV[0]
  file_guests = read_file(ARGV[0])
  uid_map = guest_uid_map

  i = 0
  file_guests.each do |file_guest|
    guest_id = uid_map[file_guest[0]]
    if guest_id
      metadata = file_guest[1]
      update_guest guest_id, metadata
      i += 1
    else
      puts "Could not find guest #{file_guest[0]} in the guest list (no update!)."
    end
  end

  puts "Successfully updated #{i} guests."
end

main()