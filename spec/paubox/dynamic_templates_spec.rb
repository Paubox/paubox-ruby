# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Paubox::DynamicTemplates do
  before { Paubox.configure { |c| c.api_key = 'test_key' } }

  let(:url) { 'https://api.paubox.com/v1/email/dynamic_templates/5' }
  let(:file) do
    Tempfile.new(['tpl', '.html']).tap do |f|
      f.write('<p>{{name}}</p>')
      f.close
    end
  end
  # pb_email_api DynamicTemplates show: serialized DynamicTemplate, no envelope.
  let(:show_body) do
    { id: 5, api_customer_id: 9, name: 'appointment-confirmation', body: '<p>old</p>', metadata: nil,
      created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }.to_json
  end

  def name_part(req)
    req.body[/name="data\[name\]"\r\n\r\n(.*?)\r\n/m, 1]
  end

  describe '#update' do
    it 'keeps the existing name when none is given' do
      stub_request(:get, url).to_return(status: 200, body: show_body)
      stub_request(:patch, url).to_return(status: 200, body: show_body)

      Paubox::DynamicTemplates.find(5).update(file.path)

      expect(WebMock).to(have_requested(:patch, url).with { |req| name_part(req) == 'appointment-confirmation' })
    end

    it 'omits data[name] when no name is known' do
      stub_request(:patch, url).to_return(status: 200, body: show_body)

      Paubox::DynamicTemplates.new('id' => 5).update(file.path)

      expect(WebMock).to(have_requested(:patch, url).with do |req|
        !req.body.include?('data[name]') && req.body.include?('data[body]')
      end)
    end

    it 'sends a given name' do
      stub_request(:patch, url).to_return(status: 200, body: show_body)

      Paubox::DynamicTemplates.new('id' => 5, 'name' => 'old').update(file.path, 'renamed')

      expect(WebMock).to(have_requested(:patch, url).with { |req| name_part(req) == 'renamed' })
    end
  end
end
