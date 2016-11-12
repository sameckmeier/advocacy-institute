#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

AUTH_KEYS = [:username, :password, :client_id, :client_token]
ITEM_FIELD_TO_DEDUPE = 'title'
ITEM_FILTER = { 'Scheduling Status' => 'Date confirmed' }
SCHEDULING_STATUS_FIELD_ID = 133224490
SCHEDULING_STATUS_VALUE_FILTER = [3]

def run(options)
  podio_client = Podio::Client.new(options)
  podio_items = Podio::Items.new(podio_client)

  puts "Requesting items\n"
  filters = { 'filters' => { SCHEDULING_STATUS_FIELD_ID => SCHEDULING_STATUS_VALUE_FILTER }}
  items = podio_items.find_all(options[:app_id], filters)
  puts "Successfully requested #{items.count} items\n\n"

  puts "Deduping #{items.count} items"
  items = Podio::Items.dedupe(items, ITEM_FIELD_TO_DEDUPE)
  puts "Successful dedupe -- items count: #{items.count}\n\n"

  puts "Posting items"
  items.each_with_idex do |item, index|
    puts "********Posting #{index}  #{decoded_json_items.count}"
    podio_items.post(options[:new_app_id], item)
    puts "********Successfully posted resource to #{slug}\n"
  end

  puts "Successfully posted items"
end

# Podio::Client handles authenticating and HTTP requests to the Podio api
module Podio
  class Client
    def initialize(args)
      @url = 'https://api.podio.com'
      @username = args[:username]
      @password = args[:password]
      @client_id = args[:client_id]
      @client_secret = args[:client_secret]
      @oauth_token = authenticate({
        'username' => args[:username],
        'password' => args[:password],
        'client_id' => args[:client_id],
        'client_secret' => args[:client_secret],
        'grant_type' => 'password'
      })
    end

    def authenticate(params)
      token = nil

      headers = default_headers({
        content_type: 'application/x-www-form-urlencoded',
        accept: 'application/x-www-form-urlencoded'
      })

      encoded_params = URI.encode_www_form(params)
      res = post("#{@url}/oauth/token", encoded_params, headers)
      oauth_hsh = JSON.parse(res)
      token = oauth_hsh["access_token"]

      token
    end

    def get(slug, headers=nil)
      payload = nil

      uri = uri(slug)
      request = request(uri)
      res = request.get(uri, headers || headers())

      handle_http_code(res, "#{res.code} ERROR: Failed GET request for #{slug}")

      payload = res.body
      payload
    end

    def post(slug, params, headers=nil)
      payload = nil

      uri = uri(slug)
      request = request(uri)

      res = request.post(uri.path, params, headers || headers())

      handle_http_code(res, "#{res.code} ERROR: Failed POST request for #{slug} --- #{res.body}")

      payload = res.body
      payload
    end

    private

    def uri(slug)
      URI("#{@url}/#{slug}")
    end

    def headers(args={})
      headers = default_headers(args)
      headers = headers.merge(authentication_headers()) if @oauth_token

      headers
    end

    def default_headers(args={})
      {
        'Content-Type' => args[:content_type] || 'application/json',
        'Accept'=> args[:accept] || 'application/json'
      }
    end

    def authentication_headers()
      { 'Authorization' => "OAuth2 #{@oauth_token}" }
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      http
    end

    def handle_http_code(response, error_msg)
      unless response.is_a?(Net::HTTPSuccess)
        throw error_msg
      end
    end
  end

  # Podio::Items is an interface to the Podio items' api and has class methods for filtering and deduping
  class Items
    def initialize(client)
      @client = client
    end

    def find_all(app_id, filters=nil)
      items = nil
      base_slug = "/item/app/#{app_id}"

      if filters
        encoded_filters = JSON.generate(filters)
        items = @client.post("#{base_slug}/filter/", encoded_filters)
      else
        items = @client.get("#{base_slug}/")
      end

      items = JSON.parse(items)['items']
      items
    end

    def post(app_id, items)
      @client.post("item/app/#{app_id}/", body)
    end

    def self.dedupe(items, field)
      items.uniq { |obj| obj[field] }
    end
  end
end
