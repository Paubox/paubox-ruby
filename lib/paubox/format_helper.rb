# frozen_string_literal: true

module Paubox
  # Utility methods for Message and MailToMessage
  module FormatHelper
    require 'base64'
    BASE64_REGEX = %r{\A(?:[A-Za-z0-9+/]{4}\r?\n?)*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?\z}.freeze

    def base64_encoded?(value)
      return false unless value.is_a?(String)

      !value.strip.match(BASE64_REGEX).nil?
    end

    def base64_encode_if_needed(str)
      return str if base64_encoded?(str.to_s)

      Base64.encode64(str.to_s)
    end

    # Converts hash keys to strings and maps them to expected JSON key.
    # Also converts hashes in shallow arrays.
    def convert_keys_to_json_version(hash)
      converted = {}
      hash.each_pair do |key, val|
        converted[ruby_to_json_key(key)] = val.is_a?(Hash) ? convert_keys_to_json_version(val) : val
        next unless val.is_a?(Array)

        val.each_with_index { |el, i| val[i] = convert_keys_to_json_version(el) if el.is_a?(Hash) }
      end
      converted
    end

    def ruby_to_json_key(key)
      { reply_to: 'reply-to', html_content: 'text/html', text_content: 'text/plain',
        filename: 'fileName', file_name: 'fileName', content_type: 'contentType',
        allow_non_tls: 'allowNonTLS', force_secure_notification: 'forceSecureNotification' }[key] || key.to_s
    end

    # def get_values_whitelist(*vals)
    #   vals.map { |k| next unless mail[k]; [ruby_to_json_key(k), mail[k]] }.to_h
    # end

    def string_or_array_to_array(object)
      case object
      when String
        a = object.split(',').map { |str| squish(str) }
      when Array
        a = object.map { |s| squish(s) }
      else
        return []
      end
      a.reject(&:empty?)
    end

    def squish(str)
      str.to_s.split.join(' ')
    end
  end
end
