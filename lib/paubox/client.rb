# frozen_string_literal: true

module Paubox
  # Client sends API requests to Paubox API
  class Client
    require 'cgi'
    require 'rest-client'
    require 'ostruct'
    attr_reader :api_key, :api_host, :api_protocol, :api_version

    # Deprecated: api_user is no longer used for authentication or URLs.
    # It is kept only for backward compatibility and has no effect on requests.
    attr_reader :api_user

    def initialize(args = {})
      args = defaults.merge(args)
      @api_key = args[:api_key]
      @api_user = args[:api_user] # deprecated no-op, kept for backward compatibility
      @api_host = args[:api_host]
      @api_protocol = args[:api_protocol]
      @api_version = args[:api_version]
      @test_mode = args[:test_mode]
      @api_base_endpoint = api_base_endpoint
    end

    def api_status
      url = request_endpoint('status')
      RestClient.get(url, accept: :json)
    end

    def send_mail(mail)
      case mail
      when Mail::Message
        allow_non_tls = mail.allow_non_tls.nil? ? false : mail.allow_non_tls
        payload = MailToMessage.new(mail, allow_non_tls: allow_non_tls)
                               .send_message_payload
      when Hash
        payload = Message.new(mail).send_message_payload
      when Paubox::Message, Paubox::TemplatedMessage
        payload = mail.send_message_payload
      end
      url = request_endpoint(mail.is_a?(Paubox::TemplatedMessage) ? 'templated_messages' : 'messages')
      response = RestClient.post(url, payload, auth_header)
      if mail.class == Mail::Message
        mail.source_tracking_id = JSON.parse(response.body)['sourceTrackingId']
      end
      JSON.parse(response.body)
    end
    alias deliver_mail send_mail

    def email_disposition(source_tracking_id)
      url = "#{request_endpoint('message_receipt')}?sourceTrackingId=#{source_tracking_id}"
      response = RestClient.get(url, auth_header)
      email_disposition = Paubox::EmailDisposition.new(JSON.parse(response.body))
    end
    alias message_receipt email_disposition

    def schedule_mail(mail, scheduled_at)
      case mail
      when Mail::Message
        allow_non_tls = mail.allow_non_tls.nil? ? false : mail.allow_non_tls
        msg_payload = MailToMessage.new(mail, allow_non_tls: allow_non_tls).send_message_payload
        msg_data = JSON.parse(msg_payload)['data']['message']
      when Hash
        msg_data = Message.new(mail).send_message_payload
        msg_data = JSON.parse(msg_data)['data']['message']
      when Paubox::Message
        msg_data = JSON.parse(mail.send_message_payload)['data']['message']
      end
      payload = { data: { message: msg_data, scheduled_at: scheduled_at } }.to_json
      url = request_endpoint('schedule')
      response = RestClient.post(url, payload, auth_header)
      JSON.parse(response.body)
    end

    def get_scheduled(source_tracking_id)
      url = request_endpoint("schedule/#{source_tracking_id}")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def reschedule(source_tracking_id, scheduled_at)
      url = request_endpoint("schedule/#{source_tracking_id}")
      payload = { scheduled_at: scheduled_at }.to_json
      response = RestClient.patch(url, payload, auth_header)
      JSON.parse(response.body)
    end

    def cancel_scheduled(source_tracking_id)
      url = request_endpoint("schedule/#{source_tracking_id}/cancel")
      response = RestClient.post(url, nil, auth_header)
      JSON.parse(response.body)
    end

    def list_receiving_domains
      url = request_endpoint('receiving/domains')
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def create_receiving_domain(slug: nil)
      url = request_endpoint('receiving/domains')
      payload = { slug: slug }.compact.to_json
      response = RestClient.post(url, payload, auth_header)
      JSON.parse(response.body)
    end

    def get_receiving_domain(id)
      url = request_endpoint("receiving/domains/#{id}")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def delete_receiving_domain(id)
      url = request_endpoint("receiving/domains/#{id}")
      response = RestClient.delete(url, auth_header)
      JSON.parse(response.body)
    end

    def list_receiving_mailboxes(domain_id)
      url = request_endpoint("receiving/domains/#{domain_id}/mailboxes")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def create_receiving_mailbox(domain_id, name:, password:, quota_bytes: nil)
      url = request_endpoint("receiving/domains/#{domain_id}/mailboxes")
      payload = { name: name, password: password, quota_bytes: quota_bytes }.compact.to_json
      response = RestClient.post(url, payload, auth_header)
      JSON.parse(response.body)
    end

    def get_receiving_mailbox(domain_id, mailbox_id)
      url = request_endpoint("receiving/domains/#{domain_id}/mailboxes/#{mailbox_id}")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def delete_receiving_mailbox(domain_id, mailbox_id)
      url = request_endpoint("receiving/domains/#{domain_id}/mailboxes/#{mailbox_id}")
      response = RestClient.delete(url, auth_header)
      JSON.parse(response.body)
    end

    def list_received_emails(limit: nil, after: nil, before: nil)
      params = { limit: limit, after: after, before: before }.compact
      query = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      url = request_endpoint('receiving')
      url = "#{url}?#{query}" unless query.empty?
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def get_received_email(email_id)
      url = request_endpoint("receiving/#{email_id}")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def get_received_email_attachment(email_id, blob_id)
      url = request_endpoint("receiving/#{email_id}/attachments/#{blob_id}")
      RestClient.get(url, auth_header)
    end

    def list_webhook_endpoints
      url = request_endpoint('webhook_endpoints')
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def create_webhook_endpoint(target_url:, events:, signing_key: nil, api_key: nil, active: true)
      url = request_endpoint('webhook_endpoints')
      payload = { target_url: target_url, events: events, active: active,
                  signing_key: signing_key, api_key: api_key }.compact.to_json
      response = RestClient.post(url, payload, auth_header)
      JSON.parse(response.body)
    end

    def get_webhook_endpoint(id)
      url = request_endpoint("webhook_endpoints/#{id}")
      response = RestClient.get(url, auth_header)
      JSON.parse(response.body)
    end

    def update_webhook_endpoint(id, **params)
      url = request_endpoint("webhook_endpoints/#{id}")
      response = RestClient.patch(url, params.to_json, auth_header)
      JSON.parse(response.body)
    end

    def delete_webhook_endpoint(id)
      url = request_endpoint("webhook_endpoints/#{id}")
      response = RestClient.delete(url, auth_header)
      JSON.parse(response.body)
    end

    def send_request(method: :get, payload: {}, path: '')
      url = request_endpoint(path)

      RestClient::Request.execute(method: method, url: url, payload: payload, headers: auth_header)
    end

    private

    def auth_header
      { accept: :json,
        content_type: :json,
        Authorization: "Token token=#{@api_key}" }
    end

    def api_base_endpoint
      "#{api_protocol}#{api_host}/#{api_version}/email"
    end

    def request_endpoint(endpoint)
      "#{api_base_endpoint}/#{endpoint}"
    end

    def defaults
      { api_key: Paubox.configuration.api_key,
        api_user: Paubox.configuration.api_user, # deprecated, unused
        api_host: 'api.paubox.com',
        api_protocol: 'https://',
        api_version: 'v1',
        test_mode: false }
    end

    # recursively converts a nested Hash into OpenStruct
    def to_open_struct(hash)
      OpenStruct.new(hash.each_with_object({}) do |(key, val), memo|
        memo[key] = val.is_a?(Hash) ? to_open_struct(val) : val
      end)
    end
  end
end
