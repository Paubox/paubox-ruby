# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Paubox::WebhooksClient do
  let(:api_key)     { 'scoped-test-key' }
  let(:client)      { described_class.new(api_key: api_key) }
  let(:endpoint_id) { '2ec66c21-bf48-48eb-8d28-f80b2d6b77c7' }
  let(:base)        { 'https://api.paubox.com/v1/webhooks/endpoints' }

  let(:endpoint) do
    {
      'id' => endpoint_id,
      'target_url' => 'https://hooks.example.com/paubox',
      'status' => 'active',
      'events' => ['forms.submission.created'],
      'created_at' => '2026-10-09T01:43:41.639968+00:00',
      'updated_at' => '2026-10-09T01:43:41.639968+00:00'
    }
  end

  describe 'configuration' do
    it 'builds the documented base URL' do
      expect(base).to eq(
        "#{described_class::WEBHOOKS_PROTOCOL}#{described_class::WEBHOOKS_HOST}" \
        "#{described_class::WEBHOOKS_BASE}/endpoints"
      )
    end

    it 'falls back to Paubox.configuration.webhooks_api_key' do
      Paubox.configure { |c| c.webhooks_api_key = 'from-config' }
      stub_request(:get, base).to_return(
        status: 200, body: { 'data' => [], 'page_info' => {} }.to_json
      )

      described_class.new.list_webhook_endpoints

      expect(
        a_request(:get, base).with(headers: { 'Authorization' => 'Bearer from-config' })
      ).to have_been_made.once
      Paubox.configure { |c| c.webhooks_api_key = nil }
    end

    it 'raises before any request when no key is configured' do
      expect { described_class.new(api_key: nil).list_webhook_endpoints }
        .to raise_error(ArgumentError, /api_key is required/)
      expect(a_request(:get, base)).not_to have_been_made
    end
  end

  describe '#list_webhook_endpoints' do
    it 'sends a Bearer header and returns the document' do
      stub_request(:get, base).to_return(
        status: 200,
        body: { 'data' => [endpoint], 'page_info' => { 'count' => 1, 'items' => 50 } }.to_json
      )

      result = client.list_webhook_endpoints

      expect(
        a_request(:get, base).with(headers: { 'Authorization' => "Bearer #{api_key}" })
      ).to have_been_made.once
      expect(result['data'].first['id']).to eq(endpoint_id)
    end

    it 'keeps page_info, where count is the total not the page length' do
      stub_request(:get, base).to_return(
        status: 200,
        body: { 'data' => [endpoint], 'page_info' => { 'count' => 2, 'items' => 1 } }.to_json
      )

      result = client.list_webhook_endpoints

      expect(result['page_info']['count']).to eq(2)
      expect(result['data'].length).to eq(1)
    end

    it 'sends pagination when given' do
      url = "#{base}?page=2&items=1"
      stub_request(:get, url).to_return(
        status: 200, body: { 'data' => [], 'page_info' => {} }.to_json
      )

      client.list_webhook_endpoints(page: 2, items: 1)

      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe '#create_webhook_endpoint' do
    let(:created) { endpoint.merge('signing_secret' => 'whsec_abc123') }

    it 'returns the signing secret, which the service sends only here' do
      stub_request(:post, base).to_return(
        status: 201,
        body: { 'data' => created, 'message' => 'Store this signing_secret now' }.to_json
      )

      result = client.create_webhook_endpoint(
        target_url: 'https://hooks.example.com/paubox',
        events: ['forms.submission.created']
      )

      expect(result['signing_secret']).to eq('whsec_abc123')
      expect(result['id']).to eq(endpoint_id)
    end

    it 'posts target_url and events as JSON' do
      stub_request(:post, base).to_return(status: 201, body: { 'data' => created }.to_json)

      client.create_webhook_endpoint(
        target_url: 'https://hooks.example.com/paubox',
        events: ['forms.submission.created']
      )

      expect(
        a_request(:post, base).with(
          body: { target_url: 'https://hooks.example.com/paubox',
                  events: ['forms.submission.created'] }.to_json
        )
      ).to have_been_made.once
    end

    it 'wraps a single event in an array' do
      stub_request(:post, base).to_return(status: 201, body: { 'data' => created }.to_json)

      client.create_webhook_endpoint(target_url: 'https://e.test/h', events: 'forms.submission.created')

      expect(
        a_request(:post, base).with(
          body: { target_url: 'https://e.test/h', events: ['forms.submission.created'] }.to_json
        )
      ).to have_been_made.once
    end

    it 'validates locally before sending' do
      expect { client.create_webhook_endpoint(target_url: '', events: ['x']) }
        .to raise_error(ArgumentError, /target_url/)
      expect { client.create_webhook_endpoint(target_url: 'https://e.test/h', events: []) }
        .to raise_error(ArgumentError, /events/)
      expect(a_request(:post, base)).not_to have_been_made
    end

    # The catalog belongs to the service and grows without a gem release, so an
    # unrecognised name must reach the server rather than be rejected here.
    it 'does not validate event names' do
      stub_request(:post, base).to_return(status: 201, body: { 'data' => created }.to_json)

      client.create_webhook_endpoint(target_url: 'https://e.test/h', events: ['some.future.event'])

      expect(
        a_request(:post, base).with(
          body: { target_url: 'https://e.test/h', events: ['some.future.event'] }.to_json
        )
      ).to have_been_made.once
    end
  end

  describe '#get_webhook_endpoint' do
    it 'unwraps the data envelope' do
      stub_request(:get, "#{base}/#{endpoint_id}")
        .to_return(status: 200, body: { 'data' => endpoint }.to_json)

      result = client.get_webhook_endpoint(endpoint_id)

      expect(result['id']).to eq(endpoint_id)
      expect(result['status']).to eq('active')
      # The secret exists only on the create response.
      expect(result).not_to have_key('signing_secret')
    end

    it 'rejects a non-UUID id before any request' do
      expect { client.get_webhook_endpoint('not-a-uuid') }
        .to raise_error(ArgumentError, /must be a UUID/)
      expect(a_request(:get, %r{/endpoints/})).not_to have_been_made
    end

    it 'rejects a traversal id before any request' do
      expect { client.get_webhook_endpoint('../endpoints') }
        .to raise_error(ArgumentError, /must be a UUID/)
    end
  end

  describe '#update_webhook_endpoint' do
    it 'sends only the fields given' do
      stub_request(:patch, "#{base}/#{endpoint_id}").to_return(
        status: 200, body: { 'data' => endpoint.merge('status' => 'disabled') }.to_json
      )

      result = client.update_webhook_endpoint(endpoint_id, status: 'disabled')

      expect(
        a_request(:patch, "#{base}/#{endpoint_id}").with(body: { status: 'disabled' }.to_json)
      ).to have_been_made.once
      expect(result['status']).to eq('disabled')
    end

    it 'refuses an update with nothing to change' do
      expect { client.update_webhook_endpoint(endpoint_id) }
        .to raise_error(ArgumentError, /at least one of/)
    end
  end

  describe '#delete_webhook_endpoint' do
    it 'returns true on an empty 204' do
      stub_request(:delete, "#{base}/#{endpoint_id}").to_return(status: 204, body: '')

      expect(client.delete_webhook_endpoint(endpoint_id)).to be(true)
      expect(a_request(:delete, "#{base}/#{endpoint_id}")).to have_been_made.once
    end
  end

  describe 'errors' do
    it 'promotes the service message onto the exception' do
      stub_request(:post, base).to_return(
        status: 422, body: { 'message' => 'target_url: must be an https URL' }.to_json
      )

      expect { client.create_webhook_endpoint(target_url: 'http://insecure.test', events: ['x']) }
        .to raise_error(Paubox::WebhooksClient::Error, 'target_url: must be an https URL')
    end

    it 'carries the status code and names the event on a 403' do
      stub_request(:get, base).to_return(
        status: 403, body: { 'message' => "events: not entitled to 'api_mail_log_delivered'" }.to_json
      )

      begin
        client.list_webhook_endpoints
      rescue Paubox::WebhooksClient::Error => e
        expect(e.status_code).to eq(403)
        expect(e.message).to match(/not entitled/)
      end
    end

    # A duplicate target_url is 422, not 409 — mapping keyed on 409 misses it.
    it 'reports a duplicate target_url as 422' do
      stub_request(:post, base).to_return(
        status: 422, body: { 'message' => 'target_url: an endpoint already exists for this URL' }.to_json
      )

      begin
        client.create_webhook_endpoint(target_url: 'https://e.test/h', events: ['x'])
      rescue Paubox::WebhooksClient::Error => e
        expect(e.status_code).to eq(422)
        expect(e.message).to match(/already exists/)
      end
    end

    it 'falls back to a generic message when the body is not the usual shape' do
      stub_request(:get, base).to_return(status: 500, body: 'plain text failure')

      expect { client.list_webhook_endpoints }
        .to raise_error(Paubox::WebhooksClient::Error, /request failed/)
    end

    # The raising frame holds the api_key; the error must not carry it onward.
    it 'does not carry the api key on the error' do
      stub_request(:get, base).to_return(status: 500, body: 'boom')

      begin
        client.list_webhook_endpoints
      rescue Paubox::WebhooksClient::Error => e
        expect(e.message).not_to include(api_key)
        expect(e.response_body).to eq('boom')
      end
    end
  end
end
