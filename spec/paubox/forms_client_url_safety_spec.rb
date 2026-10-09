# frozen_string_literal: true

require 'spec_helper'

# Regression coverage for the URL-path interpolation blocker closed in
# 0.4.0. Every method that takes a UUID argument must reject hostile-
# shaped input (traversal, query splicing, fragments, extra path
# segments, non-UUID strings, empty string, nil) at method entry, BEFORE
# the HTTP request is prepared — otherwise a caller-supplied argument
# can retarget the request to a different endpoint on the same host,
# carrying the Bearer token along.
#
# Each case asserts on the raised ArgumentError AND on the WebMock
# request-count invariant (no matching request was ever made). Asserting
# on the raise alone is not enough: a request that silently succeeded on
# a retargeted endpoint would return a valid 2xx that a status-shape
# assertion wouldn't flag.
RSpec.describe Paubox::FormsClient, 'URL path safety' do
  let(:api_key) { 'scoped-forms-api-key' }
  let(:client)  { described_class.new(api_key: api_key) }
  let(:valid_uuid) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:another_valid_uuid) { '7c9e6679-7425-40de-944b-e07fc1f90ae7' }

  # Every hostile shape that could reasonably reach a URL-path segment.
  # Each entry is a bare Ruby value; they are NOT %-encoded first — the
  # SDK is expected to reject them at the ArgumentError layer.
  HOSTILE_INPUTS = [
    '..',
    '../stats',
    '../../api/forms/stats',
    "#{'550e8400-e29b-41d4-a716-446655440000'}/archive?x=1",
    "#{'550e8400-e29b-41d4-a716-446655440000'}?customer_id=999",
    "#{'550e8400-e29b-41d4-a716-446655440000'}#/../another",
    "#{'550e8400-e29b-41d4-a716-446655440000'}/../other/stats",
    'not-a-uuid',
    "1' OR '1'='1",
    '',
    nil,
    12345 # non-string types too
  ].freeze

  # form_id-only methods (the argument is used in the URL path).
  form_id_only_methods = {
    find_form:       ->(c, id) { c.find_form(id) },
    update_form:     ->(c, id) { c.update_form(id, title: 'x') },
    archive_form:    ->(c, id) { c.archive_form(id) },
    unarchive_form:  ->(c, id) { c.unarchive_form(id) },
    list_submissions: ->(c, id) { c.list_submissions(id) },
    submissions_csv: ->(c, id) { c.submissions_csv(id) },
    get_form:        ->(c, id) { c.get_form(id) },
    submit_form:     ->(c, id) { c.submit_form(id, form_data: { x: 1 }) },
    copy_form:       ->(c, id) { c.copy_form(id, title: 'Copy') }
  }

  form_id_only_methods.each do |method_name, call|
    describe "##{method_name}" do
      HOSTILE_INPUTS.each do |bad|
        it "rejects form_id=#{bad.inspect} before any HTTP request" do
          expect { call.call(client, bad) }
            .to raise_error(ArgumentError, /form_id must be a UUID string/)
          expect(WebMock).not_to have_requested(:any, /api\.paubox\.com/)
        end
      end
    end
  end

  describe '#submissions_csv with a submission_id' do
    # nil is the documented "all submissions" mode (falls back to the
    # base URL with no /<submission_id> segment); every other hostile
    # shape must raise.
    (HOSTILE_INPUTS - [nil]).each do |bad|
      it "rejects submission_id=#{bad.inspect} even when form_id is valid" do
        expect { client.submissions_csv(valid_uuid, submission_id: bad) }
          .to raise_error(ArgumentError, /submission_id must be a UUID string/)
        expect(WebMock).not_to have_requested(:any, /api\.paubox\.com/)
      end
    end
  end

  describe '#submission_pdf' do
    HOSTILE_INPUTS.each do |bad|
      it "rejects form_id=#{bad.inspect} before any HTTP request" do
        expect { client.submission_pdf(bad, another_valid_uuid) }
          .to raise_error(ArgumentError, /form_id must be a UUID string/)
        expect(WebMock).not_to have_requested(:any, /api\.paubox\.com/)
      end

      it "rejects submission_id=#{bad.inspect} when form_id is valid" do
        expect { client.submission_pdf(valid_uuid, bad) }
          .to raise_error(ArgumentError, /submission_id must be a UUID string/)
        expect(WebMock).not_to have_requested(:any, /api\.paubox\.com/)
      end
    end
  end

  describe 'valid UUIDs are unchanged in the URL' do
    let(:find_url) { "https://api.paubox.com/v1/forms/api/forms/#{valid_uuid}" }

    it 'sends the UUID verbatim (no double-encoding) for valid input' do
      stub_request(:get, find_url)
        .to_return(status: 200,
                   body: { 'data' => { 'id' => valid_uuid, 'title' => 't' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      client.find_form(valid_uuid)

      expect(a_request(:get, find_url)).to have_been_made.once
    end
  end
end
