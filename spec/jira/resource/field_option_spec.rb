require 'spec_helper'
require 'cgi'

describe JIRA::Resource::FieldOption do
  let(:client_stub_class) do
    Class.new do
      attr_accessor :options, :field_options_cache

      def initialize
        @options = { rest_base_path: '/jira/rest/api/3' }
      end

      def Field
        @field_factory ||= Class.new do
          def name_to_id(field_name)
            field_name.to_s
          end
        end.new
      end
    end
  end

  let(:client) { client_stub_class.new }
  let(:factory) { JIRA::Resource::FieldOptionFactory.new(client) }
  let(:issue_key) { 'TEST-1' }
  let(:field_name) { 'customfield_10000' }
  let(:encoded_issue) { CGI.escape(issue_key) }
  let(:editmeta_path) { "/jira/rest/api/3/issue/#{encoded_issue}/editmeta" }
  let(:response_body) do
    {
      'fields' => {
        field_name => {
          'allowedValues' => [
            { 'id' => '1', 'value' => 'Option 1' },
            { 'id' => '2', 'value' => 'Option 2' }
          ]
        }
      }
    }.to_json
  end

  describe '#all' do
    it 'returns field options fetched from editmeta' do
      response = instance_double(Net::HTTPOK, body: response_body)
      allow(client).to receive(:get).with(editmeta_path).and_return(response)

      options = factory.all(field_name:, issue_key:)

      expect(options.map(&:value)).to eq(['Option 1', 'Option 2'])
      expect(options).to all(be_a(described_class))
      expect(client).to have_received(:get).once
    end

    it 'returns cached options without hitting the API again' do
      response = instance_double(Net::HTTPOK, body: response_body)
      allow(client).to receive(:get).with(editmeta_path).and_return(response)

      first_call = factory.all(field_name:, issue_key:)
      second_call = factory.all(field_name:, issue_key:)

      expect(first_call).to eq(second_call)
      expect(client).to have_received(:get).once
    end

    it 'returns an empty array when the field has no allowed values' do
      response = instance_double(Net::HTTPOK, body: { 'fields' => {} }.to_json)
      allow(client).to receive(:get).with(editmeta_path).and_return(response)

      options = factory.all(field_name:, issue_key:)

      expect(options).to eq([])
    end

    it 'returns an empty array when Jira responds with an error' do
      response = instance_double(Net::HTTPResponse, body: '')
      allow(client).to receive(:get).with(editmeta_path).and_raise(
        JIRA::HTTPError.new(response)
      )

      expect(factory.all(field_name:, issue_key:)).to eq([])
    end
  end
end

