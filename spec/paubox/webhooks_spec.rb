# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Paubox::Client do
  let(:client) { Paubox::Client.new(api_key: 'test_key') }
  let(:base) { client.send(:api_base_endpoint) }

  before do
    Paubox.configure { |c| c.api_key = 'test_key' }
  end

  describe '#list_webhook_endpoints' do
    it 'returns webhook endpoints' do
      stub_request(:get, "#{base}/webhook_endpoints")
        .to_return(body: [{ id: 1, target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], active: true }].to_json)
      result = client.list_webhook_endpoints
      expect(result.length).to eq 1
      expect(result.first['target_url']).to eq 'https://example.com/hook'
    end
  end

  describe '#create_webhook_endpoint' do
    it 'creates a webhook endpoint' do
      stub_request(:post, "#{base}/webhook_endpoints")
        .with(body: { target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], active: true }.to_json)
        .to_return(status: 201, body: { message: 'Webhook created!', data: { id: 1, target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], active: true } }.to_json)
      result = client.create_webhook_endpoint(target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'])
      expect(result['message']).to eq 'Webhook created!'
      expect(result['data']['id']).to eq 1
    end

    it 'passes optional signing_key and api_key' do
      stub_request(:post, "#{base}/webhook_endpoints")
        .with(body: { target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], active: true, signing_key: 'sk_123', api_key: 'ak_456' }.to_json)
        .to_return(status: 201, body: { message: 'Webhook created!', data: { id: 2 } }.to_json)
      result = client.create_webhook_endpoint(target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], signing_key: 'sk_123', api_key: 'ak_456')
      expect(result['data']['id']).to eq 2
    end
  end

  describe '#get_webhook_endpoint' do
    it 'returns a webhook endpoint by id' do
      stub_request(:get, "#{base}/webhook_endpoints/1")
        .to_return(body: { data: { id: 1, target_url: 'https://example.com/hook', events: ['api_mail_log_delivered'], active: true } }.to_json)
      result = client.get_webhook_endpoint(1)
      expect(result['data']['id']).to eq 1
      expect(result['data']['target_url']).to eq 'https://example.com/hook'
    end
  end

  describe '#update_webhook_endpoint' do
    it 'updates a webhook endpoint' do
      stub_request(:patch, "#{base}/webhook_endpoints/1")
        .with(body: { target_url: 'https://example.com/updated' }.to_json)
        .to_return(body: { message: 'Webhook updated!', data: { id: 1, target_url: 'https://example.com/updated' } }.to_json)
      result = client.update_webhook_endpoint(1, target_url: 'https://example.com/updated')
      expect(result['message']).to eq 'Webhook updated!'
      expect(result['data']['target_url']).to eq 'https://example.com/updated'
    end

    it 'updates events' do
      stub_request(:patch, "#{base}/webhook_endpoints/1")
        .with(body: { events: ['api_mail_log_opened', 'api_mail_log_delivered'] }.to_json)
        .to_return(body: { message: 'Webhook updated!', data: { id: 1, events: ['api_mail_log_opened', 'api_mail_log_delivered'] } }.to_json)
      result = client.update_webhook_endpoint(1, events: ['api_mail_log_opened', 'api_mail_log_delivered'])
      expect(result['data']['events'].length).to eq 2
    end
  end

  describe '#delete_webhook_endpoint' do
    it 'deletes a webhook endpoint' do
      stub_request(:delete, "#{base}/webhook_endpoints/1")
        .to_return(body: { message: 'Webhook deleted!', data: { id: 1 } }.to_json)
      result = client.delete_webhook_endpoint(1)
      expect(result['message']).to eq 'Webhook deleted!'
    end
  end
end
