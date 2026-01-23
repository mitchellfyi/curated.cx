# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DnsVerifier, type: :service do
  let(:dns_resolver) { instance_double(Resolv::DNS) }

  before do
    allow(Resolv::DNS).to receive(:new).and_return(dns_resolver)
    allow(dns_resolver).to receive(:timeouts=)
  end

  describe '.verify' do
    it 'delegates to instance verify' do
      allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("192.168.1.100")
      a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
      allow(dns_resolver).to receive(:getresources).and_return([ a_record ])

      result = described_class.verify(hostname: "example.com")

      expect(result[:verified]).to be true
    end
  end

  describe '#initialize' do
    it 'accepts hostname and expected_target' do
      verifier = described_class.new(hostname: "example.com", expected_target: "curated.cx")

      expect(verifier.hostname).to eq("example.com")
      expect(verifier.expected_target).to eq("curated.cx")
    end

    it 'uses default target from ENV when not provided' do
      allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("custom.target.com")

      verifier = described_class.new(hostname: "example.com")

      expect(verifier.expected_target).to eq("custom.target.com")
    end

    it 'falls back to curated.cx when DNS_TARGET not set' do
      allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_call_original

      verifier = described_class.new(hostname: "example.com")

      expect(verifier.expected_target).to eq("curated.cx")
    end
  end

  describe '#apex_domain?' do
    it 'returns true for apex domains (two parts)' do
      verifier = described_class.new(hostname: "example.com", expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be true

      verifier = described_class.new(hostname: "test.io", expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be true
    end

    it 'returns false for subdomains (three or more parts)' do
      verifier = described_class.new(hostname: "www.example.com", expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be false

      verifier = described_class.new(hostname: "blog.news.example.com", expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be false
    end

    it 'returns false for blank hostname' do
      verifier = described_class.new(hostname: "", expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be false

      verifier = described_class.new(hostname: nil, expected_target: "curated.cx")
      expect(verifier.apex_domain?).to be false
    end
  end

  describe '#verify' do
    context 'with blank hostname' do
      it 'returns error for nil hostname' do
        verifier = described_class.new(hostname: nil, expected_target: "curated.cx")

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to eq("Hostname is required")
      end

      it 'returns error for empty hostname' do
        verifier = described_class.new(hostname: "", expected_target: "curated.cx")

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to eq("Hostname is required")
      end
    end

    context 'with apex domain (A record verification)' do
      let(:verifier) { described_class.new(hostname: "example.com", expected_target: "192.168.1.100") }

      context 'when target is an IP address' do
        it 'verifies when A record matches expected IP' do
          a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([ a_record ])

          result = verifier.verify

          expect(result[:verified]).to be true
          expect(result[:records]).to eq([ "192.168.1.100" ])
        end

        it 'fails when A record does not match expected IP' do
          a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.200"))
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([ a_record ])

          result = verifier.verify

          expect(result[:verified]).to be false
          expect(result[:error]).to include("A records point to")
          expect(result[:error]).to include("192.168.1.200")
          expect(result[:error]).to include("expected 192.168.1.100")
        end

        it 'verifies when any A record matches expected IP (multiple records)' do
          a_record1 = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.50"))
          a_record2 = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([ a_record1, a_record2 ])

          result = verifier.verify

          expect(result[:verified]).to be true
          expect(result[:records]).to include("192.168.1.50", "192.168.1.100")
        end
      end

      context 'when target is a hostname' do
        let(:verifier) { described_class.new(hostname: "example.com", expected_target: "canonical.example.com") }

        it 'resolves target hostname and verifies A record matches' do
          target_ip = IPAddr.new("192.168.1.100")
          allow(dns_resolver).to receive(:getaddress)
            .with("canonical.example.com")
            .and_return(target_ip)

          a_record = instance_double(Resolv::DNS::Resource::IN::A, address: target_ip)
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([ a_record ])

          result = verifier.verify

          expect(result[:verified]).to be true
          expect(result[:records]).to eq([ "192.168.1.100" ])
        end

        it 'fails when A record does not match resolved target IP' do
          target_ip = IPAddr.new("192.168.1.100")
          domain_ip = IPAddr.new("192.168.1.200")
          allow(dns_resolver).to receive(:getaddress)
            .with("canonical.example.com")
            .and_return(target_ip)

          a_record = instance_double(Resolv::DNS::Resource::IN::A, address: domain_ip)
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([ a_record ])

          result = verifier.verify

          expect(result[:verified]).to be false
          expect(result[:error]).to include("A records point to 192.168.1.200")
          expect(result[:error]).to include("expected 192.168.1.100 (canonical.example.com)")
        end
      end

      context 'when no A records found' do
        it 'returns error' do
          allow(dns_resolver).to receive(:getresources)
            .with("example.com", Resolv::DNS::Resource::IN::A)
            .and_return([])

          result = verifier.verify

          expect(result[:verified]).to be false
          expect(result[:error]).to eq("No A records found for example.com")
        end
      end
    end

    context 'with subdomain (CNAME verification)' do
      let(:verifier) { described_class.new(hostname: "www.example.com", expected_target: "curated.cx") }

      it 'verifies when CNAME matches expected target exactly' do
        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME,
          name: Resolv::DNS::Name.create("curated.cx."))
        allow(dns_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return([ cname_record ])

        result = verifier.verify

        expect(result[:verified]).to be true
        expect(result[:records]).to eq([ "curated.cx" ])
      end

      it 'verifies when CNAME ends with expected target (trailing dot)' do
        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME,
          name: Resolv::DNS::Name.create("subdomain.curated.cx."))
        allow(dns_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return([ cname_record ])

        result = verifier.verify

        expect(result[:verified]).to be true
        expect(result[:records]).to eq([ "subdomain.curated.cx" ])
      end

      it 'fails when CNAME does not match expected target' do
        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME,
          name: Resolv::DNS::Name.create("wrong.example.com."))
        allow(dns_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return([ cname_record ])

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to include("CNAME points to wrong.example.com")
        expect(result[:error]).to include("expected curated.cx")
      end

      it 'fails when no CNAME records found' do
        allow(dns_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return([])

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to eq("No CNAME record found for www.example.com")
      end

      it 'is case insensitive for CNAME comparison' do
        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME,
          name: Resolv::DNS::Name.create("CURATED.CX."))
        allow(dns_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return([ cname_record ])

        result = verifier.verify

        expect(result[:verified]).to be true
      end
    end

    context 'error handling' do
      let(:verifier) { described_class.new(hostname: "example.com", expected_target: "192.168.1.100") }

      it 'handles Resolv::ResolvError gracefully' do
        allow(dns_resolver).to receive(:getresources)
          .and_raise(Resolv::ResolvError.new("DNS lookup failed"))

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to eq("DNS resolution error: DNS lookup failed")
      end

      it 'handles generic errors gracefully' do
        allow(dns_resolver).to receive(:getresources)
          .and_raise(StandardError.new("Network timeout"))

        result = verifier.verify

        expect(result[:verified]).to be false
        expect(result[:error]).to eq("Verification error: Network timeout")
      end
    end
  end

  describe 'timeout configuration' do
    it 'sets DNS resolver timeouts' do
      expect(dns_resolver).to receive(:timeouts=).with([ 2, 2, 2 ])

      verifier = described_class.new(hostname: "example.com", expected_target: "192.168.1.100")
      a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
      allow(dns_resolver).to receive(:getresources).and_return([ a_record ])

      verifier.verify
    end
  end

  describe 'ip_address? detection' do
    # Testing through verify behavior
    let(:verifier) { described_class.new(hostname: "example.com", expected_target: target) }

    context 'when expected_target is a valid IP' do
      let(:target) { "192.168.1.100" }

      it 'treats it as an IP address (direct comparison)' do
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
        allow(dns_resolver).to receive(:getresources).and_return([ a_record ])

        # Should NOT call getaddress since target is an IP
        expect(dns_resolver).not_to receive(:getaddress)

        result = verifier.verify
        expect(result[:verified]).to be true
      end
    end

    context 'when expected_target is a hostname' do
      let(:target) { "canonical.example.com" }

      it 'resolves the target hostname first' do
        target_ip = IPAddr.new("192.168.1.100")
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: target_ip)
        allow(dns_resolver).to receive(:getresources).and_return([ a_record ])
        expect(dns_resolver).to receive(:getaddress).with("canonical.example.com").and_return(target_ip)

        result = verifier.verify
        expect(result[:verified]).to be true
      end
    end
  end

  describe DnsVerifier::ResolutionError do
    it 'is a StandardError subclass' do
      expect(DnsVerifier::ResolutionError.superclass).to eq(StandardError)
    end

    it 'can be raised and caught' do
      expect {
        raise DnsVerifier::ResolutionError, "Custom error"
      }.to raise_error(DnsVerifier::ResolutionError, "Custom error")
    end
  end
end
