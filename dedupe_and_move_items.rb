require 'optparse'
require 'net/http'
require 'json'
require 'uri'

options = {}

OptionParser.new do |parser|
  parser.on("--email EMAIL", "Ypur podio account email") do |v|
    options[:email] = v
  end

  parser.on("--password PASSWORD", "Your podio account password") do |v|
    options[:password] = v
  end

  parser.on("--client-id CLIENT-ID", "Your personal podio api client id") do |v|
    options[:client_id] = v
  end

  parser.on("--client-secret CLIENT-SECRET", "Your personal podio api client secret") do |v|
    options[:client_secret] = v
  end

  parser.on("--app-id APP-ID", "Your podio app id from which you want to extract items") do |v|
    options[:app_id] = v
  end

  parser.on("--new-app-id NEW-APP-ID", "Your podio app id that you want to recieve items") do |v|
    options[:new_app_id] = v
  end
end.parse!

def run(options)
  scheduling_status_value_id = 133224490
  scheduling_status_value_filter = [3]
  item_field_to_dedupe = 'title'

  podio_client = Podio::Client.new(options)
  podio_items = Podio::Items.new(podio_client)

  puts "Requesting items\n"
  filters = { 'filters' => { scheduling_status_value_id => scheduling_status_value_filter }}
  items = podio_items.find_all(options[:app_id], filters)
  puts "Successfully requested #{items.count} items\n\n"

  puts "Deduping #{items.count} items"
  items = Podio::Items.dedupe(items, item_field_to_dedupe)
  puts "Successful dedupe -- items count: #{items.count}\n\n"

  puts "Posting items"
  items.each_with_idex do |item, index|
    puts "********Posting #{index} of #{items.count}"
    podio_items.clone_to_app(options[:new_app_id], item)
    puts "********Successfully posted item\n"
  end

  puts "Successfully posted items"
end

# Podio::Client handles authenticating and HTTP requests to the Podio api
module Podio
  class Client
    def initialize(args)
      @url = 'https://api.podio.com'
      @oauth_token = authenticate({
        'username' => args[:email],
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

    def authentication_headers
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

    def clone_to_app(app_id, item)
      cloned_item_fields = self.class.extract_fields_to_clone(item)
      create(app_id, cloned_item_fields)
    end

    def create(app_id, fields)
      encoded_fields = JSON.generate({ 'fields' => fields })
      @client.post("item/app/#{app_id}/", encoded_fields)
    end

    def self.dedupe(items, field)
      items.uniq { |obj| obj[field] }
    end

    def self.extract_fields_to_clone(item)
      cloned = {}

      fields = item['fields']
      fields.each do |field|
        k = field['external_id']
        v = extract_value(field['type'], field['values'][0])

        cloned[k] = v
      end

      cloned
    end

    private

    def self.extract_value(type, value)
      val = value

      case type
      when 'date'
        val = { 'start' => val['start'], 'end' => val['end'] }
      when 'category'
        val = val['value']['id']
      else
        val = val['value']
      end

      val
    end
  end
end

run(options)
