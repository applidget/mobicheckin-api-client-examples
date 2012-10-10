#!/usr/bin/ruby
#
# Script which download all guest badges into a directory
#
# API Reference: https://app.mobicheckin.com/api
#
# Usage: $ MOBICHECKIN_API_TOKEN=XXXXXX \
#          MOBICHECKIN_EVENT_ID=0000000 \
#          ./download_badges
#
# Author: Sebastien Saunier (@ssaunier)
# Company: Applidget, editor of MobiCheckin (http://www.mobicheckin.com)
# License: MIT

require "open-uri"
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

BADGE_FOLDER = File.join(File.expand_path(File.dirname(__FILE__)), "badges")

def create_http
  http = Net::HTTP.new("app.mobicheckin.com", 443)
  http.use_ssl = true
  http.ca_path = '/etc/ssl/certs'
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.verify_depth = 5
  http
end

def guest_badges
  badges = Hash.new
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
      if guest.elements["badge-url"]
        badge_url = guest.elements["badge-url"].text
        uid = guest.elements["uid"].text
        badges[uid] = badge_url
      end
    end
  end
  badges
end

def download_badge(url, path)
  File.open(path, 'wb') do |fo|
    fo.write open(url).read
  end
end

def main
  unless File.directory? BADGE_FOLDER
    puts "Creating badge folder #{BADGE_FOLDER}..."
    Dir.mkdir BADGE_FOLDER
  end
  puts "Fetching guest list..."
  badges = guest_badges
  puts "Guest list successfully fetched. Downloading all PDF badges..."
  badges.each do |uid, badge_url|
    puts "Downloading #{uid}.pdf ..."
    download_badge badge_url, File.join(BADGE_FOLDER, "#{uid}.pdf")
  end
  puts "Done!"
end

main()