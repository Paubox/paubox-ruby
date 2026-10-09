# frozen_string_literal: true

require 'cgi'
require 'json'
require 'rest-client'

module Paubox
  # Client for the Paubox webhooks service.
  #
  # Authenticates with a scoped API key sent as "Authorization: Bearer <key>",
  # the same scheme as FormsClient and unlike the Email API's "Token token=".
  # Which events a key may subscribe to is decided by its scopes; asking for
  # one it is not scoped for is refused with 403.
  class WebhooksClient
    WEBHOOKS_HOST     = 'api.paubox.com'
    WEBHOOKS_PROTOCOL = 'https://'
    # The public gateway exposes only /v1/webhooks/endpoints and rewrites it
    # onto the service's own /v1/endpoints, so the producers' event-ingest
    # route is unreachable from here. The bare base is deliberately unrouted;
    # every request below carries the /endpoints resource.
    WEBHOOKS_BASE     = '/v1/webhooks'

    TIMEOUT_SECONDS = 30

    UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    # Raised on any non-2xx response. Carries only status_code / url /
    # response_body so error reporters that capture raising-frame locals never
    # see the Authorization header or api_key.
    class Error < StandardError
      attr_reader :status_code, :url, :response_body

      def initialize(message, status_code: nil, url: nil, response_body: nil)
        super(message)
        @status_code   = status_code
        @url           = url
        @response_body = response_body
      end
    end

    def initialize(args = {})
      @host     = args[:host]     || WEBHOOKS_HOST
      @protocol = args[:protocol] || WEBHOOKS_PROTOCOL
      @base     = args[:base]     || WEBHOOKS_BASE
      @api_key  = args[:api_key]  ||
                  (Paubox.configuration && Paubox.configuration.webhooks_api_key)
    end

    # Lists the endpoints this key can act on. Endpoints carrying an event the
    # key is not scoped for are filtered out by the service, so this is what
    # the key may manage rather than everything on the account.
    #
    # Returns the full document: 'data' plus 'page_info'. Note
    # page_info['count'] is the total number of matching endpoints, not the
    # length of this page.
    def list_webhook_endpoints(page: nil, items: nil)
      query = { page: page, items: items }.compact
      url   = endpoint_url
      url   = "#{url}?#{URI.encode_www_form(query)}" unless query.empty?

      parse(request(method: :get, url: url, headers: auth_headers))
    end

    # Subscribes a URL to one or more events.
    #
    # The returned hash carries 'signing_secret', which the service sends only
    # here — it is absent from get_webhook_endpoint and from the list. Store it
    # on receipt; a lost secret means replacing the endpoint.
    #
    # Event names are not validated here on purpose: the catalog belongs to the
    # service and grows without a gem release. An unknown event comes back as
    # 422, one this key is not scoped for as 403.
    def create_webhook_endpoint(target_url:, events:)
      raise ArgumentError, 'target_url is required' if target_url.nil? || target_url.to_s.empty?
      raise ArgumentError, 'events must not be empty' if events.nil? || Array(events).empty?

      payload = { target_url: target_url, events: Array(events) }.to_json
      response = request(
        method: :post, url: endpoint_url,
        headers: auth_headers(content_type: :json), payload: payload
      )
      unwrap_data(parse(response))
    end

    def get_webhook_endpoint(id)
      assert_uuid!(id, 'id')
      unwrap_data(parse(request(method: :get, url: endpoint_url(id), headers: auth_headers)))
    end

    # Partial update: only the arguments given are sent, so changing
    # target_url leaves events and status untouched. status accepts
    # 'active' or 'disabled'.
    def update_webhook_endpoint(id, target_url: nil, status: nil, events: nil)
      assert_uuid!(id, 'id')

      body = {}
      body[:target_url] = target_url unless target_url.nil?
      body[:status]     = status unless status.nil?
      body[:events]     = Array(events) unless events.nil?
      raise ArgumentError, 'provide at least one of target_url:, status:, events:' if body.empty?

      response = request(
        method: :patch, url: endpoint_url(id),
        headers: auth_headers(content_type: :json), payload: body.to_json
      )
      unwrap_data(parse(response))
    end

    # Deletes an endpoint, stopping every event on it. The service answers 204
    # with no body, so this returns true rather than a document.
    def delete_webhook_endpoint(id)
      assert_uuid!(id, 'id')
      request(method: :delete, url: endpoint_url(id), headers: auth_headers)
      true
    end

    private

    def endpoint_url(id = nil)
      base = "#{@protocol}#{@host}#{@base}/endpoints"
      id.nil? ? base : "#{base}/#{encode_segment(id)}"
    end

    def auth_headers(extra = {})
      if @api_key.nil? || @api_key.to_s.empty?
        raise ArgumentError, 'api_key is required for this endpoint. Pass a scoped ' \
                             'API key: Paubox::WebhooksClient.new(api_key: ...), or set ' \
                             'Paubox.configuration.webhooks_api_key'
      end

      { authorization: "Bearer #{@api_key}", accept: :json }.merge(extra)
    end

    def assert_uuid!(value, name)
      return if value.is_a?(String) && value.match?(UUID_RE)

      raise ArgumentError, "#{name} must be a UUID string (received #{value.inspect})"
    end

    def encode_segment(value)
      CGI.escape(value.to_s)
    end

    def parse(response)
      body = response.body.to_s
      body.empty? ? nil : JSON.parse(body)
    end

    # Single resources arrive wrapped as {"data" => {...}}. Unwrapped so
    # callers get the endpoint rather than an envelope carrying nothing else.
    #
    # list_webhook_endpoints deliberately skips this: its envelope also carries
    # 'page_info', which a caller paginating needs.
    def unwrap_data(parsed)
      parsed.is_a?(Hash) && parsed.key?('data') ? parsed['data'] : parsed
    end

    # Funnels every request through RestClient::Request.execute so we can
    # always set an explicit timeout (rest-client's default is nil) and
    # translate ExceptionWithResponse into Paubox::WebhooksClient::Error,
    # which carries only status_code / url / response_body — never the
    # Authorization header or api_key. Keeps the Bearer token out of any error
    # reporter that captures raising-frame locals.
    #
    # Unlike FormsClient the service's own message is promoted onto the
    # exception when present, so a caller sees "target_url: must be an https
    # URL" rather than only a status code.
    def request(method:, url:, headers: {}, payload: nil)
      RestClient::Request.execute(
        method: method, url: url, payload: payload,
        headers: headers, timeout: TIMEOUT_SECONDS
      )
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
      code     = response && response.code
      raise Error.new(
        service_message(response) ||
          "Paubox webhooks API request failed: #{e.class.name.split('::').last} " \
          "(status #{code || 'unknown'})",
        status_code:   code,
        url:           url,
        response_body: response && response.body
      )
    end

    # The service answers failures as {"message": "..."}; anything else falls
    # back to the generic message above.
    def service_message(response)
      return nil unless response

      parsed = JSON.parse(response.body.to_s)
      parsed.is_a?(Hash) && parsed['message'].is_a?(String) ? parsed['message'] : nil
    rescue JSON::ParserError
      nil
    end
  end
end
