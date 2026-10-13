# frozen_string_literal: true

require 'json'
require 'paubox/version'
require 'paubox/client'
require 'paubox/dynamic_templates'
require 'paubox/format_helper'
require 'paubox/mail_to_message'
require 'paubox/message'
require 'paubox/templated_message'
require 'paubox/email_disposition'
require 'paubox/form'
require 'paubox/form_submission'
require 'paubox/forms_client'
require 'mail/paubox'

module Paubox
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :api_key, :forms_api_key

    # Deprecated: api_user is no longer used by the Email API client.
    # Kept only for backward compatibility; it has no effect on requests.
    attr_accessor :api_user
  end
end
