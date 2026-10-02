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

  let(:email_id) { '0b7f3c1e-9a4d-4c55-8f2e-6d1a2b3c4d5e' }
  let(:attachment_id) { '5e4d3c2b-1a0f-4e9d-8c7b-6a5f4e3d2c1b' }
  let(:attachment) do
    { id: attachment_id, filename: 'report.pdf', content_type: 'application/pdf', size: 2048,
      content_id: nil, download_url: "#{base}/receiving/#{email_id}/attachments/#{attachment_id}" }
  end

  describe '#list_received_emails' do
    it 'returns emails keyed by their Paubox email_id' do
      item = { email_id: email_id, from: [{ name: 'Sender', address: 'sender@example.com' }],
               to: [{ name: nil, address: 'inbox@test.inbound.paubox.email' }], subject: nil,
               received_at: '2026-10-01T12:00:00Z', has_attachment: true, spam: false, size: 4096,
               domain: 'test.inbound.paubox.email' }
      stub_request(:get, "#{base}/receiving")
        .to_return(body: { object: 'list', data: [item], has_more: false }.to_json)
      result = client.list_received_emails
      expect(result['data'].first['email_id']).to eq email_id
    end

    it 'passes pagination params' do
      stub_request(:get, "#{base}/receiving?limit=10&after=#{email_id}")
        .to_return(body: { object: 'list', data: [], has_more: false }.to_json)
      result = client.list_received_emails(limit: 10, after: email_id)
      expect(result['has_more']).to eq false
    end

    it 'passes search, sort and ascending params' do
      stub_request(:get, "#{base}/receiving?before=#{email_id}&search=lab+results&sort=received_at&ascending=false")
        .to_return(body: { object: 'list', data: [], has_more: false }.to_json)
      result = client.list_received_emails(before: email_id, search: 'lab results', sort: 'received_at',
                                           ascending: false)
      expect(result['data']).to eq []
    end
  end

  describe '#get_received_email' do
    it 'returns an email by its Paubox email_id with attachment ids' do
      detail = { email_id: email_id, from: [{ name: nil, address: 'sender@example.com' }], to: [], cc: [],
                 subject: 'Test', date: nil, received_at: '2026-10-01T12:00:00Z', message_id: ['<a@example.com>'],
                 in_reply_to: nil, references: nil, spam: false, spam_score: nil, text_body: 'hi', html_body: nil,
                 attachments: [attachment], size: 4096,
                 authentication: { spf: 'pass', dkim: 'pass', dmarc: 'pass' },
                 domain: 'test.inbound.paubox.email', headers: [{ name: 'Subject', value: 'Test' }] }
      stub_request(:get, "#{base}/receiving/#{email_id}")
        .to_return(body: { data: detail }.to_json)
      result = client.get_received_email(email_id)
      expect(result['data']['subject']).to eq 'Test'
      expect(result['data']['attachments'].first['id']).to eq attachment_id
    end
  end

  describe '#get_received_email_attachment' do
    let(:bytes) { "%PDF-1.7\n\x00\xFF\xFE binary".b }

    it 'downloads raw attachment bytes by attachment id without parsing JSON' do
      stub_request(:get, "#{base}/receiving/#{email_id}/attachments/#{attachment_id}")
        .with(headers: { 'Accept' => '*/*', 'Authorization' => 'Token token=test_key' })
        .to_return(body: bytes, headers: { 'Content-Type' => 'application/pdf',
                                           'Content-Disposition' => 'attachment; filename="report.pdf"' })
      response = client.get_received_email_attachment(email_id, attachment_id)
      expect(response.body.b).to eq bytes
      expect(response.headers[:content_type]).to eq 'application/pdf'
      expect(response.headers[:content_disposition]).to eq 'attachment; filename="report.pdf"'
    end

    it 'returns the body when no filename is known' do
      stub_request(:get, "#{base}/receiving/#{email_id}/attachments/#{attachment_id}")
        .to_return(body: 'plain', headers: { 'Content-Type' => 'application/octet-stream' })
      response = client.get_received_email_attachment(email_id, attachment_id)
      expect(response.body).to eq 'plain'
      expect(response.headers).not_to include(:content_disposition)
    end
  end
end
