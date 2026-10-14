# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Paubox do
  it 'has a version number' do
    expect(Paubox::VERSION).not_to be nil
  end

  it 'loads JSON itself, so plain-Ruby callers need not require it' do
    require 'open3'
    lib = File.expand_path('../lib', __dir__)
    out, status = Open3.capture2e(RbConfig.ruby, '-I', lib, '-e',
                                  'require "paubox"; print({ a: 1 }.to_json, JSON.parse("[1]"))')
    expect([status.success?, out]).to eq [true, '{"a":1}[1]']
  end

  describe '#configure' do
    before do
      Paubox.configure do |config|
        config.api_key = 'test_key'
        config.api_user = 'test_user'
      end
    end

    it 'Sets the API key' do
      client = Paubox::Client.new
      expect(client.api_key).to eq 'test_key'
    end

    it 'Sets the API user' do
      client = Paubox::Client.new
      expect(client.api_user).to eq 'test_user'
    end
  end
end
