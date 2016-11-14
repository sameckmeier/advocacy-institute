require 'csv'
require 'time'
require 'optparse'
require 'net/http'
require 'json'
require 'uri'

options = {}

OptionParser.new do |parser|
  parser.on("--email EMAIL", "Your podio account email") do |v|
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

  parser.on("--path-to-import PATH", "Path to import file") do |v|
    options[:path_to_import] = v
  end
end.parse!

def run(options)
  scheduling_status_value_id = 133224490
  scheduling_status_value_filter = [3]
  item_field_to_dedupe = 'title'

  podio_client = Podio::Client.new(options)
  podio_items = Podio::Items.new(podio_client)
  podio_tasks = Podio::Tasks.new(podio_client)

  puts "Requesting items\n"
  filters = { 'filters' => { scheduling_status_value_id => scheduling_status_value_filter }}
  items = podio_items.find_all(options[:app_id], filters)
  puts "Successfully requested #{items.count} items\n\n"

  puts "Deduping #{items.count} items"
  items = Podio::Items.dedupe(items, item_field_to_dedupe)
  puts "Successful dedupe -- items count: #{items.count}\n\n"

  puts "Posting items"
  items.each_with_index do |item, index|
    puts "********"
    puts "Posting #{index + 1} of #{items.count}"

    new_item = podio_items.clone_to_app(options[:new_app_id], item.raw)

    puts "Creating task for item\n"
    new_task = podio_tasks.associate_to_item(new_item)
    puts "Successfully created task\n"
    puts "Successfully posted item\n"
  end

  puts "Successfully posted items"
end

module Podio
  # Podio::Client handles authenticating and HTTP requests to the Podio api
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

  # Podio::Item is a wrapper for raw items
  class Item
    attr_reader :raw, :id, :app_id

    def initialize(raw)
      @fields = build(raw['fields'])
      @app_id = raw['app_item_id']
      @id = raw['item_id']
      @raw = raw
    end

    def method_missing(m, *args, &block)
      if @fields.keys.include?(m)
        return @fields[m]
      else
        super
      end
    end

    def respond_to_missing?(m, include_private = false)
      @fields.keys.include?(m) || super
    end

    private
    def build(fields)
      keys = []
      values = []
      fields.each do |f|
        keys << key(f['label'])
        values << value(f['values'][0])
      end

      Hash[keys.zip(values)]
    end

    def key(raw_key)
      key = ""

      key = raw_key.split(' ').delete_if { |str| !str.match(/[\w]/) }
      key = key.join('_').downcase.to_sym

      key
    end

    def value(raw_value)
      val = raw_value

      if raw_value.class == Hash
        val = raw_value['value'] if raw_value.keys.include?('value')
      end

      val
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

      items = JSON.parse(items)['items'].map { |raw| Item.new(raw) }
      items
    end

    def clone_to_app(app_id, item)
      cloned_item_fields = self.class.extract_fields_to_clone(item)
      create(app_id, cloned_item_fields)
    end

    def create(app_id, fields)
      encoded_fields = JSON.generate({ 'fields' => fields })
      raw = @client.post("item/app/#{app_id}/", encoded_fields)
      raw = JSON.parse(raw)

      item = Item.new(raw)
    end

    def self.dedupe(items, field)
      items.uniq { |item| item.raw[field] }
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

  # Podio::Tasks is an interface to the Podio tasks' api and associating with an item
  class Tasks
    def initialize(client)
      @client = client
    end

    def create(fields)
      encoded_fields = JSON.generate(fields)
      @client.post("task/", encoded_fields)
    end

    def associate_to_item(item)
      title = "Create Agenda for #{item.raw['title']}"
      time = Time.parse(item.time_date_of_meeting['start']) - (60 * 60 * 24 * 7)

      fields = {
        'text' => title,
        'private' => false,
        'ref_type' => "item",
        'ref_id' => item.id,
        'due_date' => time.strftime("%Y-%m-%d")
      }

      create(fields)
    end
  end

  # Podio::Importer reads a csv, builds item fields, and posts them to provided app 
  class Importer
    def initialize(client, podio_items, csv_path, app_id)
      @client = client
      @podio_items = podio_items
      @csv_path = csv_path
      @app_id = app_id
    end

    def run()
      app = app()

      arrays = read_csv()
      keys = arrays.shift
      vals = arrays

      app_fields = app_fields(app['fields'])
      items = items(keys, vals, app_fields)

      import_csv(items)
    end

    private

    def import_csv(items)
      items.each do |item|
        @podio_items.create(@app_id, item)
      end
    end

    def read_csv
      CSV.read(@csv_path)
    end

    def app
      encoded_app = @client.get("app/#{@app_id}")
      JSON.parse(encoded_app)
    end

    def items(keys, val_arrays, app_fields)
      items = []

      val_arrays.each { |arr| items << item(keys, arr, app_fields) unless arr.compact.empty? }

      items
    end

    def item(keys, values, app_fields)
      item = {}

      unless values.compact.empty?
        keys.each_with_index do |k,i|
          external_id = app_fields[k][:id]
          type = app_fields[k][:type]

          value = type == 'number' ? Float(values[i]) : values[i]
          item[external_id] = value
        end
      end

      item
    end

    def app_fields(fields)
      ids = {}

      fields.each do |field|
        label = field['config']['label']
        type = field['type']
        id = field['external_id']
        ids[label] = { id: id, type: type }
      end

      ids
    end
  end
end

run(options)
