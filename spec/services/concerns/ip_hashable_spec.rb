# frozen_string_literal: true

require "rails_helper"

RSpec.describe IpHashable do
  let(:test_class) do
    Class.new do
      class << self
        include IpHashable
      end
    end
  end

  describe ".hash_ip" do
    it "returns a SHA256 hash of the IP address" do
      result = test_class.hash_ip("192.168.1.1")

      expect(result.length).to eq(64)
      expect(result).to match(/\A[a-f0-9]+\z/)
    end

    it "uses the application secret key base as salt" do
      expected = Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}")

      result = test_class.hash_ip("192.168.1.1")

      expect(result).to eq(expected)
    end

    it "returns consistent hashes for the same IP" do
      first_hash = test_class.hash_ip("192.168.1.1")
      second_hash = test_class.hash_ip("192.168.1.1")

      expect(first_hash).to eq(second_hash)
    end

    it "returns different hashes for different IPs" do
      hash_one = test_class.hash_ip("192.168.1.1")
      hash_two = test_class.hash_ip("192.168.1.2")

      expect(hash_one).not_to eq(hash_two)
    end

    context "with blank input" do
      it "returns nil for nil" do
        expect(test_class.hash_ip(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(test_class.hash_ip("")).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(test_class.hash_ip("   ")).to be_nil
      end
    end

    context "with various IP formats" do
      it "hashes IPv4 addresses" do
        result = test_class.hash_ip("10.0.0.1")
        expect(result.length).to eq(64)
      end

      it "hashes IPv6 addresses" do
        result = test_class.hash_ip("2001:0db8:85a3:0000:0000:8a2e:0370:7334")
        expect(result.length).to eq(64)
      end
    end
  end
end
