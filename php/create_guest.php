#!/usr/bin/php

<?php

/**
 * This script creates a new guest on the MobiCheckin platform for
 * a given event and a given guest category.
 *
 * API Reference: https://app.mobicheckin.com/api
 *
 * Usage:
 * $ MOBICHECKIN_API_TOKEN=XXXXXX \
 *   MOBICHECKIN_EVENT_ID=0000000 \
 *   MOBICHECKIN_GUEST_CATEGORY_ID=00000000 ./create_guest.php
 *
 * Author: Sebastien Saunier (@ssaunier)
 * Company: Applidget, editor of MobiCheckin (http://www.mobicheckin.com)
 * License: MIT
 */

function check_env($key) {
  if (empty($_ENV[$key])) {
    echo "Missing $key variable in environment. Aborting.";
    exit(1);
  }
  $GLOBALS[$key] = $_ENV[$key];
}

// Minimum configuration is set in the environment
check_env('MOBICHECKIN_API_TOKEN');
check_env('MOBICHECKIN_EVENT_ID');
check_env('MOBICHECKIN_GUEST_CATEGORY_ID');

// Exemple of Guest object to create. Here we are using an associative array.
$guest_to_create = array(
  "guest-category-id" => $MOBICHECKIN_GUEST_CATEGORY_ID,
  // "uid" => "XXXXXXX",  // Uncomment to put the UID you want (an exeternal DB id for instance.).
                          // Leave as is if you don't care, MobiCheckin will auto-generate a uid.
                          // More info here: https://applidget.zendesk.com/entries/22087398-can-i-run-multiple-import-of-my-excel-file
  "email" => "john.smith@acme.org",
  "first-name" => "John",
  "last-name" => "Smith",
  "company-name" => "Acme Inc.",
  "position" => "CEO",
  "phone-number" => "001122334455"
  // "message" => "Vegan lunch",  // Uncomment if you want a message that appear on the iOS device when the guest is checked-in.
  // "guest-metadata" => array(   // You can pass any other information abotu the guest in this hash.
  //  array("name" => "Has a dog", "value" => "Yes"),
  //  array("name" => "Birth year", "value" => "1960")
  // )
);

// Conversion function from an associative array to an XML serialized version.
// Please note that our MobiCheckin API needs an explicit type declaration for arrays
// (this is the case for the <guest-metadata /> node).
function array_to_xml(array $arr, SimpleXMLElement $xml)
{
  foreach ($arr as $k => $v) {
    if (is_array($v)) {
      $tag_name = $v;
      if (array_values($v) === $v) {  // Test if is numeric array (not associative)
        $child = $xml->addChild($k);
        $child->addAttribute("type", "array");  // Then tell ruby that this XML node is an array.
      } else if (is_numeric($k)) {
        $child = $xml->addChild("element"); // 0, 1, 2 are not valid XML node names.
      } else {
        $child = $xml->addChild($k);
      }
      array_to_xml($v, $child);
    } else {
      $xml->addChild($k, $v);
    }
  }
  return $xml;
}

// Serialize guest to XML.
$payload = array_to_xml($guest_to_create, new SimpleXMLElement('<guest/>'))->asXML();

// Call API with a POST request.
$url = "https://app.mobicheckin.com/api/v1/events/$MOBICHECKIN_EVENT_ID/guests.xml?auth_token=$MOBICHECKIN_API_TOKEN";
$ch = curl_init($url);

curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-type: text/xml', 'Content-length: ' . strlen($payload)));
curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
curl_close($ch);

// Display API answer. If it worked, you should view the XML version
// of the guest created. If not, an XML object with detailled errors
// will appear.
echo $response;
?>