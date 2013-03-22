require 'spec_helper'
require 'hashie'

describe TentValidator::ResponseExpectation::Results do
  let(:request_url) { "http://lindeichmann.example.com/ollie?foo=bar" }
  let(:request_headers) { { "Accept" => "text/plain" } }
  let(:request_body) { "Ping" }
  let(:response_headers) { { "Count" => "285", "Sugar" => "Crack from Mary Poppins" } }
  let(:response_body) { "Pong" }
  let(:env) {
    Hashie::Mash.new(
      :status => 200,
      :request_headers => request_headers,
      :request_body => request_body,
      :method => 'get',
      :url => URI(request_url),
      :body => response_body,
      :response_headers => response_headers
    )
  }
  let(:results) {
    [
      {
        :key => :response_headers,
        :assertions => [
          { :op => "test", :path => "/Count", :value => "/^\\d+$/", :type => "regexp" }
        ],
        :failed_assertions => [],
        :diff => [],
        :valid => true
      },
      {
        :key => :response_headers,
        :assertions => [
          { :op => "test", :path => "/Sugar", :value => "Sweet" }
        ],
        :failed_assertions => [
          { :op => "test", :path => "/Sugar", :value => "Sweet" }
        ],
        :diff => [
          { :op => "replace", :path => "/Sugar", :value => "Sweet" },
          { :op => "add", :path => "/Content-Type", :value => "text/plain" }
        ],
        :valid => false
      },
      {
        :key => :response_status,
        :assertions => [
          { :op => "test", :path => "", :value => 200 }
        ],
        :failed_assertions => [],
        :diff => [],
        :valid => true
      }
    ]
  }
  let(:response) { Faraday::Response.new(env) }
  let(:instance) { described_class.new(response, results) }

  describe "#as_json" do
    let(:expected_output) {
      {
        :expected => {
          :response_headers => {
            :assertions => [
              { :op => "test", :path => "/Count", :value => "/^\\d+$/", :type => "regexp" },
              { :op => "test", :path => "/Sugar", :value => "Sweet" }
            ],
            :failed_assertions => [
              { :op => "test", :path => "/Sugar", :value => "Sweet" }
            ],
            :diff => [
              { :op => "replace", :path => "/Sugar", :value => "Sweet" },
              { :op => "add", :path => "/Content-Type", :value => "text/plain" }
            ],
            :valid => false
          },
          :response_status => {
            :assertions => [
              { :op => "test", :path => "", :value => 200 }
            ],
            :failed_assertions => [],
            :diff => [],
            :valid => true
          }
        },
        :actual => {
          :request_headers => request_headers,
          :request_body => request_body,
          :request_path => "/ollie",
          :request_params => { "foo" => "bar" },
          :request_url => request_url,
          :request_method => 'GET',

          :response_headers => response_headers,
          :response_body => response_body,
          :response_status => 200
        }
      }
    }

    it "merges expectation results with actual data" do
      expect(instance.as_json).to eql(expected_output)
    end
  end
end
