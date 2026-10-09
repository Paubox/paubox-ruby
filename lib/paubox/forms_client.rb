# frozen_string_literal: true

require 'cgi'
require 'rest-client'

module Paubox
  class FormsClient
    FORMS_HOST     = 'api.paubox.com'
    FORMS_PROTOCOL = 'https://'
    FORMS_BASE     = '/v1/forms'

    TIMEOUT_SECONDS = 30

    UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    LIST_FORMS_PARAMS = %i[customer_id form_id search order order_by
                           archived active page items].freeze
    LIST_SUBMISSIONS_PARAMS = %i[submission_id order_by order page items].freeze

    # Raised on any non-2xx response from the Forms API. Carries only
    # status_code / url / response_body so error reporters that capture
    # raising-frame locals never see the Authorization header or api_key.
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
      @host     = args[:host]     || FORMS_HOST
      @protocol = args[:protocol] || FORMS_PROTOCOL
      @base     = args[:base]     || FORMS_BASE
      @api_key  = args[:api_key]  ||
                  (Paubox.configuration && Paubox.configuration.forms_api_key)
    end

    def get_form(form_id)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/public/form_data/#{encode_segment(form_id)}"
      response = request(method: :get, url: url, headers: { accept: :json })
      Paubox::Form.new(JSON.parse(response.body))
    end

    def submit_form(form_id, form_data:, attachments: [])
      assert_uuid!(form_id, 'form_id')
      url     = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}/submissions"
      payload = { form_data: form_data }
      payload[:attachments] = attachments unless attachments.empty?
      request(method: :post, url: url, payload: payload.to_json,
              headers: { content_type: :json, accept: :json })
    end

    def list_forms(params = {})
      url   = "#{@protocol}#{@host}#{@base}/api/forms"
      query = params.transform_keys(&:to_sym)
                    .select { |k, _v| LIST_FORMS_PARAMS.include?(k) }
      if query[:customer_id].nil?
        raise ArgumentError, 'customer_id is required for list_forms and must ' \
                             "match the API key's customer, e.g. " \
                             'client.list_forms(customer_id: 123)'
      end

      response = request(method: :get, url: url,
                         headers: auth_headers.merge(params: query))
      body     = JSON.parse(response.body)
      forms    = (body['results'] || []).map { |form| Paubox::Form.new(form) }
      { forms: forms, page_info: body['page_info'] }
    end

    def create_form(attrs)
      url      = "#{@protocol}#{@host}#{@base}/api/forms"
      response = request(method: :post, url: url, payload: attrs.to_json,
                         headers: auth_headers.merge(content_type: :json))
      JSON.parse(response.body)
    end

    def find_form(form_id)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}"
      response = request(method: :get, url: url, headers: auth_headers)
      Paubox::Form.new(JSON.parse(response.body)['data'])
    end

    def update_form(form_id, attrs)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}"
      response = request(method: :put, url: url, payload: attrs.to_json,
                         headers: auth_headers.merge(content_type: :json))
      JSON.parse(response.body)
    end

    def archive_form(form_id)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}/archive"
      response = request(method: :post, url: url, payload: '{}',
                         headers: auth_headers.merge(content_type: :json))
      JSON.parse(response.body)
    end

    def unarchive_form(form_id)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}/unarchive"
      response = request(method: :post, url: url, payload: '{}',
                         headers: auth_headers.merge(content_type: :json))
      JSON.parse(response.body)
    end

    def copy_form(form_id, title:)
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/copy"
      payload  = { form_id: form_id, title: title }
      response = request(method: :post, url: url, payload: payload.to_json,
                         headers: auth_headers.merge(content_type: :json))
      Paubox::Form.new(JSON.parse(response.body))
    end

    def form_stats(customer_id: nil)
      url     = "#{@protocol}#{@host}#{@base}/api/forms/stats"
      headers = auth_headers
      headers = headers.merge(params: { customer_id: customer_id }) unless customer_id.nil?
      response = request(method: :get, url: url, headers: headers)
      JSON.parse(response.body)
    end

    def list_submissions(form_id, params = {})
      assert_uuid!(form_id, 'form_id')
      url      = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}/submissions"
      query    = params.transform_keys(&:to_sym)
                       .select { |k, _v| LIST_SUBMISSIONS_PARAMS.include?(k) }
      response = request(method: :get, url: url,
                         headers: auth_headers.merge(params: query))
      body     = JSON.parse(response.body)
      submissions = (body['data'] || []).map { |s| Paubox::FormSubmission.new(s) }
      { submissions: submissions, total: body['total'], page: body['page'],
        items: body['items'] }
    end

    def submissions_csv(form_id, submission_id: nil)
      assert_uuid!(form_id, 'form_id')
      base = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}" \
             '/submissions/submission-csv'
      url = if submission_id.nil?
              base
            else
              assert_uuid!(submission_id, 'submission_id')
              "#{base}/#{encode_segment(submission_id)}"
            end
      request(method: :get, url: url, headers: auth_headers(accept: 'text/csv')).body
    end

    def submission_pdf(form_id, submission_id)
      assert_uuid!(form_id, 'form_id')
      assert_uuid!(submission_id, 'submission_id')
      url = "#{@protocol}#{@host}#{@base}/api/forms/#{encode_segment(form_id)}/submissions/" \
            "#{encode_segment(submission_id)}/submission-pdf"
      request(method: :get, url: url, headers: auth_headers(accept: 'application/pdf')).body
    end

    private

    def auth_headers(accept: :json)
      if @api_key.nil? || @api_key.to_s.empty?
        raise ArgumentError, "api_key is required for this endpoint. Pass a scoped " \
                             "API key with the 'forms' scope: " \
                             'Paubox::FormsClient.new(api_key: ...)'
      end

      { authorization: "Bearer #{@api_key}", accept: accept }
    end

    def assert_uuid!(value, name)
      return if value.is_a?(String) && value.match?(UUID_RE)

      raise ArgumentError, "#{name} must be a UUID string (received #{value.inspect})"
    end

    def encode_segment(value)
      CGI.escape(value.to_s)
    end

    # Funnels every request through RestClient::Request.execute so we can
    # always set an explicit timeout (rest-client's default is nil) and
    # translate ExceptionWithResponse into Paubox::FormsClient::Error,
    # which carries only status_code / url / response_body — never the
    # Authorization header or api_key. Keeps the Bearer token out of any
    # error reporter that captures raising-frame locals.
    def request(method:, url:, headers: {}, payload: nil)
      RestClient::Request.execute(
        method:  method,
        url:     url,
        payload: payload,
        headers: headers,
        timeout: TIMEOUT_SECONDS
      )
    rescue RestClient::ExceptionWithResponse => e
      response = e.response
      raise Error.new(
        "Paubox Forms API request failed: #{e.class.name.split('::').last} " \
        "(status #{response && response.code || 'unknown'})",
        status_code:   response && response.code,
        url:           url,
        response_body: response && response.body
      )
    end
  end
end
