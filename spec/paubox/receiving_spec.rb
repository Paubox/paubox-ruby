# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Paubox::Client do
  let(:client) { Paubox::Client.new(api_key: 'test_key') }
  let(:base) { client.send(:api_base_endpoint) }

  before do
    Paubox.configure { |c| c.api_key = 'test_key' }
  end

  describe '#list_receiving_domains' do
    it 'returns domains' do
      stub_request(:get, "#{base}/receiving/domains")
        .to_return(body: { data: [{ id: 1, domain: 'test.inbound.paubox.email' }] }.to_json)
      result = client.list_receiving_domains
      expect(result['data'].length).to eq 1
    end
  end

  describe '#create_receiving_domain' do
    it 'creates a domain with a slug' do
      stub_request(:post, "#{base}/receiving/domains")
        .with(body: { slug: 'my-domain' }.to_json)
        .to_return(status: 201, body: { data: { id: 1, domain: 'my-domain.inbound.paubox.email' } }.to_json)
      result = client.create_receiving_domain(slug: 'my-domain')
      expect(result['data']['domain']).to eq 'my-domain.inbound.paubox.email'
    end

    it 'creates a domain without a slug' do
      stub_request(:post, "#{base}/receiving/domains")
        .with(body: '{}')
        .to_return(status: 201, body: { data: { id: 2 } }.to_json)
      result = client.create_receiving_domain
      expect(result['data']['id']).to eq 2
    end
  end

  describe '#get_receiving_domain' do
    it 'returns a domain by id' do
      stub_request(:get, "#{base}/receiving/domains/1")
        .to_return(body: { data: { id: 1 } }.to_json)
      result = client.get_receiving_domain(1)
      expect(result['data']['id']).to eq 1
    end
  end

  describe '#delete_receiving_domain' do
    it 'deletes a domain' do
      stub_request(:delete, "#{base}/receiving/domains/1")
        .to_return(body: '{}')
      result = client.delete_receiving_domain(1)
      expect(result).to eq({})
    end
  end

  describe '#list_receiving_mailboxes' do
    it 'returns mailboxes for a domain' do
      stub_request(:get, "#{base}/receiving/domains/1/mailboxes")
        .to_return(body: { data: [{ id: 1, email: 'inbox@test.inbound.paubox.email' }] }.to_json)
      result = client.list_receiving_mailboxes(1)
      expect(result['data'].length).to eq 1
    end
  end

  describe '#create_receiving_mailbox' do
    it 'creates a mailbox' do
      stub_request(:post, "#{base}/receiving/domains/1/mailboxes")
        .with(body: { name: 'support', password: 'secret123' }.to_json)
        .to_return(status: 201, body: { data: { id: 2, email: 'support@test.inbound.paubox.email' } }.to_json)
      result = client.create_receiving_mailbox(1, name: 'support', password: 'secret123')
      expect(result['data']['email']).to eq 'support@test.inbound.paubox.email'
    end
  end

  describe '#get_receiving_mailbox' do
    it 'returns a mailbox' do
      stub_request(:get, "#{base}/receiving/domains/1/mailboxes/2")
        .to_return(body: { data: { id: 2 } }.to_json)
      result = client.get_receiving_mailbox(1, 2)
      expect(result['data']['id']).to eq 2
    end
  end

  describe '#delete_receiving_mailbox' do
    it 'deletes a mailbox' do
      stub_request(:delete, "#{base}/receiving/domains/1/mailboxes/2")
        .to_return(body: '{}')
      result = client.delete_receiving_mailbox(1, 2)
      expect(result).to eq({})
    end
  end

  describe '#list_received_emails' do
    it 'returns emails' do
      stub_request(:get, "#{base}/receiving")
        .to_return(body: { object: 'list', data: [], has_more: false }.to_json)
      result = client.list_received_emails
      expect(result['data']).to eq []
    end

    it 'passes query params' do
      stub_request(:get, "#{base}/receiving?limit=10&after=abc")
        .to_return(body: { object: 'list', data: [], has_more: false }.to_json)
      result = client.list_received_emails(limit: 10, after: 'abc')
      expect(result['has_more']).to eq false
    end
  end

  describe '#get_received_email' do
    it 'returns an email by id' do
      stub_request(:get, "#{base}/receiving/eaaaaab")
        .to_return(body: { data: { email_id: 'eaaaaab', subject: 'Test' } }.to_json)
      result = client.get_received_email('eaaaaab')
      expect(result['data']['subject']).to eq 'Test'
    end
  end

  describe '#get_received_email_attachment' do
    it 'returns attachment bytes' do
      stub_request(:get, "#{base}/receiving/eaaaaab/attachments/blob123")
        .to_return(body: 'binary-data', headers: { 'Content-Type' => 'application/pdf' })
      response = client.get_received_email_attachment('eaaaaab', 'blob123')
      expect(response.body).to eq 'binary-data'
    end
  end
end
