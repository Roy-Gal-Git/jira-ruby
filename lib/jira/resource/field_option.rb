# frozen_string_literal: true

require 'cgi'

module JIRA
  module Resource
    class FieldOptionFactory < JIRA::BaseFactory # :nodoc:
      def all(field_name:, issue_key:)
        target_class.all(@client, field_name:, issue_key:)
      end
    end

    class FieldOption < JIRA::Base
      class << self
        def all(client, field_name:, issue_key:)
          raise ArgumentError, 'field_name is required' unless field_name
          raise ArgumentError, 'issue_key is required' unless issue_key

          field_identifier = client.Field.name_to_id(field_name)
          cache_key = cache_key_for(issue_key, field_identifier)

          client.field_options_cache ||= {}
          if client.field_options_cache.key?(cache_key)
            return client.field_options_cache[cache_key]
          end

          options = fetch_from_issue_editmeta(client, issue_key, field_identifier)
          client.field_options_cache[cache_key] = options
        end

        private

        def fetch_from_issue_editmeta(client, issue_key, field_identifier)
          response = client.get(editmeta_url(client, issue_key))
          json = parse_json(response.body)
          allowed_values = json.dig('fields', field_identifier, 'allowedValues') || []

          allowed_values.map do |attrs|
            new(client, attrs:, expanded: true)
          end
        rescue JIRA::HTTPError
          []
        end

        def cache_key_for(issue_key, field_identifier)
          "#{issue_key}-#{field_identifier}"
        end

        def editmeta_url(client, issue_key)
          "#{client.options[:rest_base_path]}/issue/#{CGI.escape(issue_key)}/editmeta"
        end
      end
    end
  end
end

