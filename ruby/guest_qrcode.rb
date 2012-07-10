#!/usr/bin/ruby
# Script which creates the Google Chart url of the QR Code to put on a guest badge.
# This QR Code is then used by the MobiCheckin iOS application the day of the event.
# You can take this script as an exemple if you need to generate MobiCheckin-compatible
# QR Code yourself. The QR Code spec can be found line 64 with the `dict` variable.
#
# Usage: $ MOBICHECKIN_API_TOKEN=XXXXXX MOBICHECKIN_EVENT_ID=0000000 ./guest_qrcode.rb
#
# Author: Sebastien Saunier (@ssaunier)
# Company: Applidget, editor of MobiCheckin (http://www.mobicheckin.com)
# License: MIT

require 'cgi'
require 'net/https'
require "rexml/document"

# QR Code image width in pixes
QRCODE_WIDTH = 420

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

# Gather 20 first guests for this event
request_uri = "/api/v1/events/#{EVENT_ID}/guests.xml?page=1&auth_token=#{API_TOKEN}"
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
end
$first_guest = doc.root.elements.first

def text_value(node)
  element = $first_guest.elements[node.to_s]
  if element
    element.text
  end
end

# Generate QR Code URL for this guest
dict = {
  "UID" => text_value(:uid),  # Mandatory for MobiCheckin iOS to work
  "N" => "#{text_value(:'first-name')} #{text_value(:'last-name')}",
  "EMAIL" => text_value(:email),
  "ORG" => text_value(:'comany-name'),
  "TITLE" => text_value(:position),
  "TEL" => text_value(:number)
}

# Generate MECARD
mecard = ""
dict.each do |key, value|
  if value || key == 'N'
    mecard += "#{key}:#{value};"
  end
end
mecard += ";"

# Generate Google QR Code URL
path ="http://chart.apis.google.com/chart"
options = "chs=#{QRCODE_WIDTH}x#{QRCODE_WIDTH}&cht=qr&chld=L|1"
first_guest_qrcode_url = "#{path}?#{options}&chl=MECARD:#{CGI.escape(mecard)}"

# Display results
puts "You can visualize your first guest (#{dict["N"]}, UID=#{dict["UID"]}) QR code at the following url:"
puts first_guest_qrcode_url
`open '#{first_guest_qrcode_url}'`