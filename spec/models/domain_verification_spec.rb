# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Domain, type: :model do
  describe "verification status" do
    let(:site) { create(:site) }
    let(:domain) { create(:domain, site: site, hostname: "example.com") }

    it "defaults to pending_dns status" do
      expect(domain.status).to eq("pending_dns")
    end

    it "can transition through statuses" do
      domain.update!(status: :verified_dns)
      expect(domain.status).to eq("verified_dns")

      domain.update!(status: :ssl_pending)
      expect(domain.status).to eq("ssl_pending")

      domain.update!(status: :active)
      expect(domain.status).to eq("active")
    end

    it "can be marked as failed with error" do
      domain.update!(status: :failed, last_error: "DNS resolution failed")
      expect(domain.status).to eq("failed")
      expect(domain.last_error).to eq("DNS resolution failed")
    end
  end

  describe "#check_dns!" do
    let(:site) { create(:site) }
    let(:domain) { create(:domain, site: site, hostname: "example.com", status: :pending_dns) }
    let(:dns_resolver) { instance_double(Resolv::DNS) }

    before do
      allow(Resolv::DNS).to receive(:new).and_return(dns_resolver)
      allow(dns_resolver).to receive(:timeouts=)
      allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("192.168.1.100")
    end

    context "with apex domain and successful A record verification" do
      it "updates status to verified_dns when A record matches expected IP" do
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
        allow(dns_resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::A).and_return([ a_record ])

        result = domain.check_dns!

        expect(result[:verified]).to be true
        domain.reload
        expect(domain.status).to eq("verified_dns")
        expect(domain.verified).to be true
        expect(domain.verified_at).to be_present
        expect(domain.last_error).to be_nil
        expect(domain.last_checked_at).to be_present
      end

      it "updates status to failed when A record does not match expected IP" do
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.200"))
        allow(dns_resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::A).and_return([ a_record ])

        result = domain.check_dns!

        expect(result[:verified]).to be false
        domain.reload
        expect(domain.status).to eq("failed")
        expect(domain.last_error).to be_present
        expect(domain.last_error).to include("A records point to")
      end

      it "updates status to failed when no A records found" do
        allow(dns_resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::A).and_return([])

        result = domain.check_dns!

        expect(result[:verified]).to be false
        domain.reload
        expect(domain.status).to eq("failed")
        expect(domain.last_error).to include("No A records found")
      end

      it "handles DNS target as hostname by resolving it first" do
        allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("canonical.example.com")

        # Resolve canonical hostname to IP
        canonical_ip = IPAddr.new("192.168.1.100")
        allow(dns_resolver).to receive(:getaddress).with("canonical.example.com").and_return(canonical_ip)

        # Domain A record matches resolved IP
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: canonical_ip)
        allow(dns_resolver).to receive(:getresources).with("example.com", Resolv::DNS::Resource::IN::A).and_return([ a_record ])

        result = domain.check_dns!

        expect(result[:verified]).to be true
        domain.reload
        expect(domain.status).to eq("verified_dns")
      end
    end

    context "with subdomain and successful CNAME verification" do
      let(:subdomain) { create(:domain, site: site, hostname: "news.example.com", status: :pending_dns) }

      it "updates status to verified_dns when CNAME points to expected target" do
        allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("canonical.example.com")

        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME, name: Resolv::DNS::Name.create("canonical.example.com."))
        allow(dns_resolver).to receive(:getresources).with("news.example.com", Resolv::DNS::Resource::IN::CNAME).and_return([ cname_record ])

        result = subdomain.check_dns!

        expect(result[:verified]).to be true
        subdomain.reload
        expect(subdomain.status).to eq("verified_dns")
        expect(subdomain.last_error).to be_nil
      end

      it "updates status to failed when CNAME does not point to expected target" do
        allow(ENV).to receive(:fetch).with("DNS_TARGET", "curated.cx").and_return("canonical.example.com")

        cname_record = instance_double(Resolv::DNS::Resource::IN::CNAME, name: Resolv::DNS::Name.create("wrong.example.com."))
        allow(dns_resolver).to receive(:getresources).with("news.example.com", Resolv::DNS::Resource::IN::CNAME).and_return([ cname_record ])

        result = subdomain.check_dns!

        expect(result[:verified]).to be false
        subdomain.reload
        expect(subdomain.status).to eq("failed")
        expect(subdomain.last_error).to include("CNAME points to")
      end

      it "updates status to failed when no CNAME records found" do
        allow(dns_resolver).to receive(:getresources).with("news.example.com", Resolv::DNS::Resource::IN::CNAME).and_return([])

        result = subdomain.check_dns!

        expect(result[:verified]).to be false
        subdomain.reload
        expect(subdomain.status).to eq("failed")
        expect(subdomain.last_error).to include("No CNAME record found")
      end
    end

    context "with DNS resolution errors" do
      it "handles ResolvError gracefully" do
        allow(dns_resolver).to receive(:getresources).and_raise(Resolv::ResolvError.new("DNS resolution failed"))

        result = domain.check_dns!

        expect(result[:verified]).to be false
        expect(result[:error]).to include("DNS resolution error")
        domain.reload
        expect(domain.status).to eq("failed")
        expect(domain.last_error).to be_present
      end

      it "handles general errors gracefully" do
        allow(dns_resolver).to receive(:getresources).and_raise(StandardError.new("Network error"))

        result = domain.check_dns!

        expect(result[:verified]).to be false
        expect(result[:error]).to include("Verification error")
        domain.reload
        expect(domain.status).to eq("failed")
        expect(domain.last_error).to include("Network error")
      end
    end

    context "when already verified" do
      let(:verified_domain) { create(:domain, site: site, hostname: "verified.com", status: :verified_dns) }

      it "maintains verified_dns status when check passes again" do
        a_record = instance_double(Resolv::DNS::Resource::IN::A, address: IPAddr.new("192.168.1.100"))
        allow(dns_resolver).to receive(:getresources).with("verified.com", Resolv::DNS::Resource::IN::A).and_return([ a_record ])

        result = verified_domain.check_dns!

        expect(result[:verified]).to be true
        verified_domain.reload
        expect(verified_domain.status).to eq("verified_dns")
      end

      it "transitions to failed if verification fails" do
        allow(dns_resolver).to receive(:getresources).with("verified.com", Resolv::DNS::Resource::IN::A).and_return([])

        result = verified_domain.check_dns!

        expect(result[:verified]).to be false
        verified_domain.reload
        expect(verified_domain.status).to eq("failed")
      end
    end
  end

  describe "#next_step" do
    let(:site) { create(:site) }

    it "returns appropriate next step for pending_dns" do
      domain = create(:domain, site: site, status: :pending_dns)
      expect(domain.next_step).to include("Configure DNS")
    end

    it "returns appropriate next step for verified_dns" do
      domain = create(:domain, site: site, status: :verified_dns)
      expect(domain.next_step).to include("SSL certificate")
    end

    it "returns appropriate next step for active" do
      domain = create(:domain, site: site, status: :active)
      expect(domain.next_step).to include("active and ready")
    end

    it "returns appropriate next step for failed" do
      domain = create(:domain, site: site, status: :failed, last_error: "Test error")
      expect(domain.next_step).to include("failed")
    end
  end

  describe "#status_color" do
    let(:site) { create(:site) }

    it "returns correct color for each status" do
      expect(create(:domain, site: site, status: :pending_dns).status_color).to eq("yellow")
      expect(create(:domain, site: site, status: :verified_dns).status_color).to eq("blue")
      expect(create(:domain, site: site, status: :ssl_pending).status_color).to eq("blue")
      expect(create(:domain, site: site, status: :active).status_color).to eq("green")
      expect(create(:domain, site: site, status: :failed).status_color).to eq("red")
    end
  end
end
