# frozen_string_literal: true

require 'spec_helper'
require './spec/helpers/form_submission_helper'

RSpec.configure do |c|
  c.include Helpers::FormSubmissionHelper
end

RSpec.describe Paubox::FormsClient, 'submissions' do
  let(:api_key)       { Helpers::FormSubmissionHelper::API_KEY }
  let(:client)        { described_class.new(api_key: api_key) }
  let(:form_id)       { Helpers::FormSubmissionHelper::SUBMISSION_FORM_ID }
  let(:submission_id) { Helpers::FormSubmissionHelper::SUBMISSION_ID }
  let(:base_url)      { "https://api.paubox.com/v1/forms/api/forms/#{form_id}/submissions" }
  let(:auth_header)   { { 'Authorization' => "Bearer #{api_key}" } }

  before do
    @original_configuration = Paubox.configuration
    Paubox.configuration = nil
  end

  after do
    Paubox.configuration = @original_configuration
  end

  describe '#list_submissions' do
    let(:response_headers) { { 'Content-Type' => 'application/json' } }

    it 'makes GET request to the correct URL with the Bearer auth header' do
      stub_request(:get, base_url)
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      client.list_submissions(form_id)

      expect(a_request(:get, base_url).with(headers: auth_header))
        .to have_been_made.once
    end

    it 'passes supported query params' do
      stub_request(:get, base_url)
        .with(query: { order_by: 'created_at', order: 'desc', page: '2', items: '10' })
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      client.list_submissions(form_id, order_by: 'created_at', order: 'desc',
                                       page: 2, items: 10)

      expect(a_request(:get, base_url)
        .with(query: { order_by: 'created_at', order: 'desc', page: '2', items: '10' },
              headers: auth_header)).to have_been_made.once
    end

    it 'passes submission_id as a query param' do
      stub_request(:get, base_url)
        .with(query: { submission_id: submission_id })
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      client.list_submissions(form_id, submission_id: submission_id)

      expect(a_request(:get, base_url).with(query: { submission_id: submission_id }))
        .to have_been_made.once
    end

    it 'filters out unsupported query params' do
      stub_request(:get, base_url)
        .with(query: { page: '1' })
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      client.list_submissions(form_id, page: 1, bogus: 'nope', search: 'ignored')

      expect(a_request(:get, base_url).with(query: { page: '1' }))
        .to have_been_made.once
    end

    it 'returns submissions as Paubox::FormSubmission objects with pagination info' do
      stub_request(:get, base_url)
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      result = client.list_submissions(form_id)

      expect(result[:submissions]).to all(be_a(Paubox::FormSubmission))
      expect(result[:submissions].length).to eq 2
      expect(result[:submissions].first.id).to eq submission_id
      expect(result[:submissions].first.submitter_email).to eq 'jane@example.com'
      expect(result[:submissions].first.form_data).to eq('first_name' => 'Jane',
                                                         'last_name' => 'Smith')
      expect(result[:total]).to eq 2
      expect(result[:page]).to eq 1
      expect(result[:items]).to eq 25
    end

    it 'returns an empty submissions array when data is missing' do
      stub_request(:get, base_url)
        .to_return(status: 200, body: { 'total' => 0, 'page' => 1, 'items' => 25 }.to_json,
                   headers: response_headers)

      result = client.list_submissions(form_id)

      expect(result[:submissions]).to eq []
      expect(result[:total]).to eq 0
    end

    it 'raises ArgumentError when the client has no api_key' do
      no_key_client = described_class.new

      expect { no_key_client.list_submissions(form_id) }
        .to raise_error(ArgumentError, /api_key is required/)
      expect(a_request(:get, base_url)).not_to have_been_made
    end

    it 'raises ArgumentError when the api_key is an empty string' do
      empty_key_client = described_class.new(api_key: '')

      expect { empty_key_client.list_submissions(form_id) }
        .to raise_error(ArgumentError, /api_key is required/)
      expect(a_request(:get, base_url)).not_to have_been_made
    end

    it 'falls back to Paubox.configuration.forms_api_key' do
      Paubox.configure { |config| config.forms_api_key = 'configured-forms-key' }
      stub_request(:get, base_url)
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      described_class.new.list_submissions(form_id)

      expect(a_request(:get, base_url)
        .with(headers: { 'Authorization' => 'Bearer configured-forms-key' }))
        .to have_been_made.once
    end

    it 'accepts string keys for params' do
      stub_request(:get, base_url)
        .with(query: { order_by: 'created_at', page: '2' })
        .to_return(status: 200, body: sample_list_submissions_response.to_json,
                   headers: response_headers)

      client.list_submissions(form_id, 'order_by' => 'created_at', 'page' => 2)

      expect(a_request(:get, base_url)
        .with(query: { order_by: 'created_at', page: '2' }))
        .to have_been_made.once
    end
  end

  describe '#submissions_csv' do
    let(:csv_url)        { "#{base_url}/submission-csv" }
    let(:single_csv_url) { "#{csv_url}/#{submission_id}" }

    it 'makes GET request to the all-submissions CSV URL with the Bearer auth header' do
      stub_request(:get, csv_url)
        .to_return(status: 200, body: sample_csv_body,
                   headers: { 'Content-Type' => 'text/csv' })

      client.submissions_csv(form_id)

      expect(a_request(:get, csv_url)
        .with(headers: auth_header.merge('Accept' => 'text/csv')))
        .to have_been_made.once
    end

    it 'appends submission_id to the URL when given' do
      stub_request(:get, single_csv_url)
        .to_return(status: 200, body: sample_csv_body,
                   headers: { 'Content-Type' => 'text/csv' })

      client.submissions_csv(form_id, submission_id: submission_id)

      expect(a_request(:get, single_csv_url).with(headers: auth_header))
        .to have_been_made.once
    end

    it 'returns the CSV body as a String' do
      stub_request(:get, csv_url)
        .to_return(status: 200, body: sample_csv_body,
                   headers: { 'Content-Type' => 'text/csv' })

      csv = client.submissions_csv(form_id)

      expect(csv).to be_a(String)
      expect(csv).to eq sample_csv_body
    end

    it 'raises ArgumentError when the client has no api_key' do
      expect { described_class.new.submissions_csv(form_id) }
        .to raise_error(ArgumentError, /api_key is required/)
      expect(a_request(:get, csv_url)).not_to have_been_made
    end
  end

  describe '#submission_pdf' do
    let(:pdf_url) { "#{base_url}/#{submission_id}/submission-pdf" }

    it 'makes GET request to the correct URL with the Bearer auth header' do
      stub_request(:get, pdf_url)
        .to_return(status: 200, body: sample_pdf_body,
                   headers: { 'Content-Type' => 'application/pdf' })

      client.submission_pdf(form_id, submission_id)

      expect(a_request(:get, pdf_url)
        .with(headers: auth_header.merge('Accept' => 'application/pdf')))
        .to have_been_made.once
    end

    it 'returns the PDF bytes as a String' do
      stub_request(:get, pdf_url)
        .to_return(status: 200, body: sample_pdf_body,
                   headers: { 'Content-Type' => 'application/pdf' })

      pdf = client.submission_pdf(form_id, submission_id)

      expect(pdf).to be_a(String)
      expect(pdf).to eq sample_pdf_body
      expect(pdf).to start_with '%PDF'
    end

    it 'raises ArgumentError when the client has no api_key' do
      expect { described_class.new.submission_pdf(form_id, submission_id) }
        .to raise_error(ArgumentError, /api_key is required/)
      expect(a_request(:get, pdf_url)).not_to have_been_made
    end
  end
end
