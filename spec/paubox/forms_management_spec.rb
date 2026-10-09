# frozen_string_literal: true

require 'spec_helper'
require './spec/helpers/form_helper'

RSpec.configure do |c|
  c.include Helpers::FormHelper
end

RSpec.describe Paubox::FormsClient do
  let(:api_key) { 'scoped-forms-api-key' }
  let(:client)  { described_class.new(api_key: api_key) }
  let(:form_id) { Helpers::FormHelper::FORM_ID }
  let(:base_url) { 'https://api.paubox.com/v1/forms/api/forms' }
  let(:auth_header) { { 'Authorization' => "Bearer #{api_key}" } }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  # Other spec files may leave Paubox.configuration populated; save and
  # restore it around each example so the api_key fallback behavior is
  # tested deterministically without wiping global state for later files.
  before do
    @original_configuration = Paubox.configuration
    Paubox.configuration = nil
  end

  after do
    Paubox.configuration = @original_configuration
  end

  describe 'authentication' do
    let(:unauthenticated) { described_class.new }

    it 'raises ArgumentError from #list_forms when no api_key is set' do
      expect { unauthenticated.list_forms(customer_id: 123) }
        .to raise_error(ArgumentError, /api_key is required for this endpoint/)
    end

    it 'raises ArgumentError from #form_stats when no api_key is set' do
      expect { unauthenticated.form_stats }
        .to raise_error(ArgumentError, /api_key is required for this endpoint/)
    end

    it 'raises ArgumentError from #find_form when no api_key is set' do
      expect { unauthenticated.find_form(form_id) }
        .to raise_error(ArgumentError, /api_key is required for this endpoint/)
    end

    it 'raises ArgumentError from #create_form when no api_key is set' do
      expect { unauthenticated.create_form(sample_create_form_attrs) }
        .to raise_error(ArgumentError, /forms.*scope/)
    end

    it 'raises ArgumentError from #update_form when no api_key is set' do
      expect { unauthenticated.update_form(form_id, title: 'x') }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError from #archive_form when no api_key is set' do
      expect { unauthenticated.archive_form(form_id) }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError from #unarchive_form when no api_key is set' do
      expect { unauthenticated.unarchive_form(form_id) }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError from #copy_form when no api_key is set' do
      expect { unauthenticated.copy_form(form_id, title: 'Copy') }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError when api_key is an empty string' do
      empty_key_client = described_class.new(api_key: '')
      expect { empty_key_client.list_forms(customer_id: 123) }
        .to raise_error(ArgumentError, /api_key is required/)
    end

    it 'makes no HTTP request when api_key is missing' do
      expect { unauthenticated.list_forms(customer_id: 123) }
        .to raise_error(ArgumentError)
      expect(a_request(:get, base_url)).not_to have_been_made
    end

    it 'falls back to Paubox.configuration.forms_api_key' do
      Paubox.configure { |config| config.forms_api_key = 'configured-forms-key' }

      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      described_class.new.list_forms(customer_id: 123)

      expect(a_request(:get, base_url)
        .with(query: { 'customer_id' => '123' },
              headers: { 'Authorization' => 'Bearer configured-forms-key' }))
        .to have_been_made.once
    end

    it 'does not fall back to the Email API key (Paubox.configuration.api_key)' do
      Paubox.configure { |config| config.api_key = 'email-api-key' }

      expect { described_class.new.list_forms(customer_id: 123) }
        .to raise_error(ArgumentError, /api_key is required for this endpoint/)
      expect(a_request(:get, base_url)).not_to have_been_made
    end

    it 'prefers an explicitly passed api_key over the configuration' do
      Paubox.configure { |config| config.forms_api_key = 'configured-forms-key' }

      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      described_class.new(api_key: 'explicit-key').list_forms(customer_id: 123)

      expect(a_request(:get, base_url)
        .with(query: { 'customer_id' => '123' },
              headers: { 'Authorization' => 'Bearer explicit-key' }))
        .to have_been_made.once
    end
  end

  describe '#list_forms' do
    it 'makes GET request to /api/forms with the Bearer auth header' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      client.list_forms(customer_id: 123)

      expect(a_request(:get, base_url)
        .with(query: { 'customer_id' => '123' }, headers: auth_header))
        .to have_been_made.once
    end

    it 'raises ArgumentError when customer_id is missing' do
      expect { client.list_forms }
        .to raise_error(ArgumentError, /customer_id is required/)
      expect { client.list_forms(search: 'intake') }
        .to raise_error(ArgumentError, /customer_id is required/)
      expect(a_request(:get, base_url)).not_to have_been_made
    end

    it 'passes provided filters as query params' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123', 'search' => 'intake',
                       'order' => 'desc', 'order_by' => 'updated_at',
                       'archived' => 'false', 'active' => 'true',
                       'page' => '2', 'items' => '50' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      client.list_forms(customer_id: 123, search: 'intake', order: 'desc',
                        order_by: 'updated_at', archived: false, active: true,
                        page: 2, items: 50)

      expect(a_request(:get, base_url)
        .with(query: hash_including('search' => 'intake', 'page' => '2')))
        .to have_been_made.once
    end

    it 'ignores unknown params' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123', 'page' => '1' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      client.list_forms(customer_id: 123, page: 1, bogus: 'nope')

      expect(a_request(:get, base_url)
        .with(query: { 'customer_id' => '123', 'page' => '1' }))
        .to have_been_made.once
    end

    it 'accepts string keys for params' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123', 'search' => 'intake', 'page' => '2' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      client.list_forms('customer_id' => 123, 'search' => 'intake', 'page' => 2)

      expect(a_request(:get, base_url)
        .with(query: { 'customer_id' => '123', 'search' => 'intake', 'page' => '2' }))
        .to have_been_made.once
    end

    it 'returns forms as Paubox::Form objects with page_info' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123' })
        .to_return(status: 200, body: sample_paged_forms_response.to_json,
                   headers: json_headers)

      result = client.list_forms(customer_id: 123)

      expect(result[:forms]).to all(be_a(Paubox::Form))
      expect(result[:forms].length).to eq 2
      expect(result[:forms].first.title).to eq 'Patient Intake Form'
      expect(result[:forms].last.title).to eq 'Consent Form'
      expect(result[:page_info]).to eq('count' => 2, 'pages' => 1,
                                       'page' => 1, 'items' => 25)
    end

    it 'returns an empty forms array when results are missing' do
      stub_request(:get, base_url)
        .with(query: { 'customer_id' => '123' })
        .to_return(status: 200, body: { 'page_info' => nil }.to_json,
                   headers: json_headers)

      result = client.list_forms(customer_id: 123)

      expect(result[:forms]).to eq []
    end
  end

  describe '#create_form' do
    it 'makes POST request to /api/forms with a JSON body and auth header' do
      stub_request(:post, base_url).to_return(status: 201, body: { 'id' => form_id }.to_json,
                                              headers: json_headers)

      client.create_form(sample_create_form_attrs)

      expect(a_request(:post, base_url)
        .with(body: sample_create_form_attrs.to_json,
              headers: auth_header.merge('Content-Type' => 'application/json')))
        .to have_been_made.once
    end

    it 'returns the parsed response hash with the new form id' do
      stub_request(:post, base_url).to_return(status: 201, body: { 'id' => form_id }.to_json,
                                              headers: json_headers)

      result = client.create_form(sample_create_form_attrs)

      expect(result).to eq('id' => form_id)
    end

    it 'passes optional attrs through unchanged' do
      attrs = sample_create_form_attrs.merge(description: 'A form', signable: true,
                                             recipient: 'staff@clinic.com')
      stub_request(:post, base_url).to_return(status: 201, body: { 'id' => form_id }.to_json,
                                              headers: json_headers)

      client.create_form(attrs)

      expect(a_request(:post, base_url).with(body: attrs.to_json)).to have_been_made.once
    end
  end

  describe '#find_form' do
    let(:find_url) { "#{base_url}/#{form_id}" }

    it 'makes GET request to /api/forms/:id with the auth header' do
      stub_request(:get, find_url)
        .to_return(status: 200, body: { 'data' => sample_form_response }.to_json,
                   headers: json_headers)

      client.find_form(form_id)

      expect(a_request(:get, find_url).with(headers: auth_header))
        .to have_been_made.once
    end

    it 'returns a Paubox::Form built from the "data" value' do
      stub_request(:get, find_url)
        .to_return(status: 200, body: { 'data' => sample_form_response }.to_json,
                   headers: json_headers)

      form = client.find_form(form_id)

      expect(form).to be_a(Paubox::Form)
      expect(form.id).to eq form_id
      expect(form.title).to eq 'Patient Intake Form'
      expect(form.archived?).to be false
    end
  end

  describe '#update_form' do
    let(:update_url) { "#{base_url}/#{form_id}" }
    let(:attrs) { { title: 'Renamed Form', active: false } }

    it 'makes PUT request to /api/forms/:id with only the given attrs' do
      stub_request(:put, update_url)
        .to_return(status: 200, body: sample_update_form_response.to_json,
                   headers: json_headers)

      client.update_form(form_id, attrs)

      expect(a_request(:put, update_url)
        .with(body: attrs.to_json,
              headers: auth_header.merge('Content-Type' => 'application/json')))
        .to have_been_made.once
    end

    it 'returns the parsed response hash' do
      stub_request(:put, update_url)
        .to_return(status: 200, body: sample_update_form_response.to_json,
                   headers: json_headers)

      result = client.update_form(form_id, attrs)

      expect(result).to eq('detail' => 'Form updated successfully',
                           'form_id' => form_id)
    end
  end

  describe '#archive_form' do
    let(:archive_url) { "#{base_url}/#{form_id}/archive" }

    it 'makes POST request with an empty JSON body and auth header' do
      stub_request(:post, archive_url)
        .to_return(status: 200, body: { 'detail' => 'Form archived.' }.to_json,
                   headers: json_headers)

      client.archive_form(form_id)

      expect(a_request(:post, archive_url)
        .with(body: '{}',
              headers: auth_header.merge('Content-Type' => 'application/json')))
        .to have_been_made.once
    end

    it 'returns the parsed response hash' do
      stub_request(:post, archive_url)
        .to_return(status: 200, body: { 'detail' => 'Form archived.' }.to_json,
                   headers: json_headers)

      expect(client.archive_form(form_id)).to eq('detail' => 'Form archived.')
    end
  end

  describe '#unarchive_form' do
    let(:unarchive_url) { "#{base_url}/#{form_id}/unarchive" }

    it 'makes POST request with an empty JSON body and auth header' do
      stub_request(:post, unarchive_url)
        .to_return(status: 200, body: { 'detail' => 'Form unarchived.' }.to_json,
                   headers: json_headers)

      client.unarchive_form(form_id)

      expect(a_request(:post, unarchive_url)
        .with(body: '{}', headers: auth_header))
        .to have_been_made.once
    end

    it 'returns the parsed response hash' do
      stub_request(:post, unarchive_url)
        .to_return(status: 200, body: { 'detail' => 'Form unarchived.' }.to_json,
                   headers: json_headers)

      expect(client.unarchive_form(form_id)).to eq('detail' => 'Form unarchived.')
    end
  end

  describe '#copy_form' do
    let(:copy_url) { "#{base_url}/copy" }
    let(:copied_form) do
      sample_form_response.merge('id'          => 'new-copy-uuid',
                                 'title'       => 'Copied Form',
                                 'old_form_id' => form_id)
    end

    it 'makes POST request to /api/forms/copy with form_id and title' do
      stub_request(:post, copy_url)
        .to_return(status: 201, body: copied_form.to_json, headers: json_headers)

      client.copy_form(form_id, title: 'Copied Form')

      expect(a_request(:post, copy_url)
        .with(body: { form_id: form_id, title: 'Copied Form' }.to_json,
              headers: auth_header.merge('Content-Type' => 'application/json')))
        .to have_been_made.once
    end

    it 'returns a Paubox::Form built from the top-level response' do
      stub_request(:post, copy_url)
        .to_return(status: 201, body: copied_form.to_json, headers: json_headers)

      form = client.copy_form(form_id, title: 'Copied Form')

      expect(form).to be_a(Paubox::Form)
      expect(form.id).to eq 'new-copy-uuid'
      expect(form.title).to eq 'Copied Form'
      expect(form.old_form_id).to eq form_id
    end
  end

  describe '#form_stats' do
    let(:stats_url) { "#{base_url}/stats" }

    it 'makes GET request to /api/forms/stats without query params by default' do
      stub_request(:get, stats_url)
        .to_return(status: 200, body: sample_form_stats.to_json, headers: json_headers)

      client.form_stats

      expect(a_request(:get, stats_url).with(headers: auth_header))
        .to have_been_made.once
    end

    it 'passes customer_id as a query param when given' do
      stub_request(:get, stats_url)
        .with(query: { 'customer_id' => '456' })
        .to_return(status: 200, body: sample_form_stats.to_json, headers: json_headers)

      client.form_stats(customer_id: 456)

      expect(a_request(:get, stats_url)
        .with(query: { 'customer_id' => '456' }, headers: auth_header))
        .to have_been_made.once
    end

    it 'returns the parsed stats hash' do
      stub_request(:get, stats_url)
        .to_return(status: 200, body: sample_form_stats.to_json, headers: json_headers)

      stats = client.form_stats

      expect(stats).to eq('active_form_count'       => 5,
                          'total_submission_count'  => 120,
                          'submissions_last_7_days' => 7)
    end
  end
end
