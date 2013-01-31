require 'spec_helper'

describe TentValidator do
  describe ".remote_server=" do
    it "should set remote_server" do
      server_url = "https://remote.example.org/tent"
      described_class.remote_server = server_url
      expect(described_class.remote_server).to eql(server_url)
    end
  end

  describe ".remote_auth_details=" do
    it "should set remote_auth_details" do
      auth_details = {
        :mac_key_id => 'mac-key-id',
        :mac_algorithm => 'algorithm',
        :mac_key => 'mac-key'
      }

      described_class.remote_auth_details = auth_details
      expect(described_class.remote_auth_details).to eql(auth_details)
    end
  end

  describe ".local_adapter" do
    it "should return tentd adapter" do
      adapter = described_class.local_adapter(stub(:entity => 'http://example.org'))
      expect(adapter).to_not be_nil
      expect(adapter.size).to eql(2)
      expect(adapter.first.to_s).to match(/rack\Z/)
    end
  end
end
