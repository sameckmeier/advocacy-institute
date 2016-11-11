#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

AUTH_KEYS = [:username, :password, :client_id, :client_token]
ITEM_FIELD_TO_DEDUPE = 'title'
ITEM_FILTER = { 'Scheduling Status' => 'Date confirmed' }

def run(options)
  podio_client = Podio::Client.new(options)
  podio_items = Podio::Items.new(podio_client)

  puts "Requesting items\n"
  json_items = podio_items.find_all(options[:app_id])
  puts "Successfully requested items\n\n"

  items = JSON.parse(json_items)['items']
  items = Podio::Items.dedupe(items, ITEM_FIELD_TO_DEDUPE)
  items = Podio::Items.filter_by_field(items, ITEM_FILTER)

  puts "Posting items"
  items.each_with_idex do |item, index|
    puts "********Posting #{index}  #{decoded_json_items.count}"
    podio_items.post(options[:new_app_id], item)
    puts "********Successfully posted resource to #{slug}\n"
  end

  puts "Successfully posted items"
end

module Podio
  class Client
    def initialize(args)
      @url = 'https://api.podio.com'
      @username = args[:username]
      @password = args[:password]
      @client_id = args[:client_id]
      @client_secret = args[:client_secret]
      @oauth_token = authenticate({
        username: args[:username],
        password: args[:password],
        client_id: args[:client_id],
        client_secret: args[:client_secret]
      })
    end

    def authenticate(args)
      token = nil

      args[:grant_type] = 'password'
      auth_slug = "oauth/token"
      res = post(auth_slug, args)

      oauth_hsh = JSON.parse(res)
      token = oauth_hsh["access_token"]

      token
    end

    def get(slug)
      payload = nil

      uri = add_oauth("#{@url}/#{slug}")
      res = Net::HTTP.get_response(uri)

      handle_http_code(res, "#{res.code} ERROR: Failed GET request for #{slug}")

      payload = res.body
      payload
    end

    def post(slug, body)
      payload = nil

      uri = add_oauth("#{@url}/#{slug}")
      res = Net::HTTP.post_form(uri, body)

      handle_http_code(res, "#{res.code} ERROR: Failed POST request for #{slug} --- #{res.body}")

      payload = res.body
      payload
    end

    private

    def add_oauth(uri)
      formatted_uri = URI(uri)

      params = { oauth_token: @oauth_token }
      formatted_uri.query = URI.encode_www_form(params)

      formatted_uri
    end

    def handle_http_code(response, error_msg)
      unless response.is_a?(Net::HTTPSuccess)
        throw error_msg
      end
    end
  end

  class Items
    def initialize(client)
      @client = client
    end

    def find_all(app_id)
      @client.get("item/app/#{app_id}/")
    end

    def post(app_id, body)
      @client.post("item/app/#{app_id}/", body)
    end

    def self.dedupe(items, field)
      puts "Deduping #{items.count} items"
      deduped_items = items.uniq { |obj| obj[field] }
      puts "Successful dedupe -- items count: #{deduped_items.count}\n\n"

      deduped_items
    end

    def self.filter_by_field(items, filter)
      filtered = []

      items.each do |item|
        match = true

        fields_to_check = map_fields_to_check(filter, item)

        filter.each { |k,v| match = false unless fields_to_check[k] === v }
        filtered << item if match
      end

      filtered
    end

    private

    def self.map_fields_to_check(filter, item)
      fields_to_check = {}
      field_objs = item['fields']

      field_objs.each do |field_obj|
        key = field_obj['label']
        val = field_obj['values'][0]

        if val.class == Hash && val['value'].class == Hash
          val = val['value']['text']
        end

        fields_to_check[key] = val if filter.keys.include?(key)
      end

      fields_to_check
    end
  end
end
