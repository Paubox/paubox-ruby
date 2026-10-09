# frozen_string_literal: true

require 'spec_helper'
require './spec/helpers/form_helper'

RSpec.configure do |c|
  c.include Helpers::FormHelper
end

RSpec.describe Paubox::FormsClient do
  let(:client)  { described_class.new }
  let(:form_id) { Helpers::FormHelper::FORM_ID }
  let(:get_url)  { "https://api.paubox.com/v1/forms/public/form_data/#{form_id}" }
  let(:post_url) { "https://api.paubox.com/v1/forms/api/forms/#{form_id}/submissions" }

  describe '#initialize' do
    it 'uses default host, protocol, and base' do
      expect(client.instance_variable_get(:@host)).to eq 'api.paubox.com'
      expect(client.instance_variable_get(:@protocol)).to eq 'https://'
      expect(client.instance_variable_get(:@base)).to eq '/v1/forms'
    end

    it 'allows host, protocol, and base override' do
      custom = described_class.new(host: 'localhost:3000', protocol: '', base: '')
      expect(custom.instance_variable_get(:@host)).to eq 'localhost:3000'
      expect(custom.instance_variable_get(:@protocol)).to eq ''
      expect(custom.instance_variable_get(:@base)).to eq ''
    end
  end

  describe '#get_form' do
    it 'makes GET request to the correct URL' do
      stub_request(:get, get_url)
        .to_return(status: 200, body: sample_form_response.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      client.get_form(form_id)

      expect(a_request(:get, get_url)).to have_been_made.once
    end

    it 'returns a Paubox::Form' do
      stub_request(:get, get_url)
        .to_return(status: 200, body: sample_form_response.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      form = client.get_form(form_id)

      expect(form).to be_a(Paubox::Form)
      expect(form.title).to eq 'Patient Intake Form'
      expect(form.active?).to be true
    end
  end

  describe '#submit_form' do
    it 'makes POST request to the correct URL' do
      stub_request(:post, post_url).to_return(status: 201)

      client.submit_form(form_id, form_data: sample_form_data)

      expect(a_request(:post, post_url)).to have_been_made.once
    end

    it 'sends form_data in the request body' do
      stub_request(:post, post_url).to_return(status: 201)

      client.submit_form(form_id, form_data: sample_form_data)

      expect(a_request(:post, post_url).with(body: { form_data: sample_form_data }.to_json))
        .to have_been_made.once
    end

    it 'includes attachments when provided' do
      stub_request(:post, post_url).to_return(status: 201)

      client.submit_form(form_id, form_data: sample_form_data, attachments: sample_attachments)

      expected_body = { form_data: sample_form_data, attachments: sample_attachments }.to_json
      expect(a_request(:post, post_url).with(body: expected_body)).to have_been_made.once
    end

    it 'omits attachments key when empty' do
      stub_request(:post, post_url).to_return(status: 201)

      client.submit_form(form_id, form_data: sample_form_data)

      expect(a_request(:post, post_url).with { |req| !req.body.include?('attachments') })
        .to have_been_made.once
    end

    it 'returns the HTTP response' do
      stub_request(:post, post_url).to_return(status: 201)

      response = client.submit_form(form_id, form_data: sample_form_data)

      expect(response.code).to eq 201
    end
  end
end
