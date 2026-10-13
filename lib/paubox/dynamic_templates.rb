# frozen_string_literal: true

module Paubox
  class DynamicTemplates

    attr_accessor :id, :name, :api_customer_id, :body
    
    def initialize(args = {})
      @id = args['id']
      @name = args['name']
      @api_customer_id = args['api_customer_id']
      @body = args['body']
    end

    def update(template_file_path, template_name = nil)
      path = "dynamic_templates/#{id}"
      payload = {
        data: {
          name: template_name || name,
          body: File.new(template_file_path)
        }.compact
      }

      Paubox::Client.new.send_request(method: :patch, payload: payload, path: path)
    end

    def delete
      path = "dynamic_templates/#{id}"
      Paubox::Client.new.send_request(method: :delete, path: path)
    end

    class << self
      def create(template_name, template_file_path)
        path = "dynamic_templates"
        payload = {
          data: {
            name: template_name,
            body: File.new(template_file_path) 
          }
        }
        Paubox::Client.new.send_request(method: :post, payload: payload, path: path)
      end

      def find(template_id)
        path = "dynamic_templates/#{template_id.to_s}"
        response = Paubox::Client.new.send_request(method: :get, path: path)
        data = JSON.parse(response.body)
        Paubox::DynamicTemplates.new(data)
      end

      def list
        path = "dynamic_templates"
        response = Paubox::Client.new.send_request(method: :get, path: path)
        JSON.parse(response.body)
      end
    end
  end
end
