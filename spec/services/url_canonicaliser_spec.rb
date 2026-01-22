# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UrlCanonicaliser do
  describe '.canonicalize' do
    it 'normalizes scheme to lowercase' do
      result = described_class.canonicalize('HTTP://EXAMPLE.COM/Article')
      expect(result).to eq('http://example.com/Article')
    end

    it 'normalizes host to lowercase' do
      result = described_class.canonicalize('https://EXAMPLE.COM/article')
      expect(result).to eq('https://example.com/article')
    end

    it 'removes tracking parameters' do
      result = described_class.canonicalize('https://example.com/article?utm_source=google&utm_medium=email&other=keep')
      expect(result).to eq('https://example.com/article?other=keep')
    end

    it 'removes trailing slash from paths' do
      result = described_class.canonicalize('https://example.com/article/')
      expect(result).to eq('https://example.com/article')
    end

    it 'keeps root path slash' do
      result = described_class.canonicalize('https://example.com/')
      expect(result).to eq('https://example.com/')
    end

    it 'handles complex URLs with multiple tracking params' do
      url = 'https://example.com/article?utm_source=google&fbclid=123&gclid=456&ref=homepage&keep=this'
      result = described_class.canonicalize(url)
      expect(result).to eq('https://example.com/article?keep=this')
    end

    it 'handles URLs with no query parameters' do
      result = described_class.canonicalize('https://example.com/article')
      expect(result).to eq('https://example.com/article')
    end

    it 'handles URLs with only tracking parameters' do
      result = described_class.canonicalize('https://example.com/article?utm_source=google&utm_medium=email')
      expect(result).to eq('https://example.com/article')
    end

    it 'raises InvalidUrlError for invalid URLs' do
      expect {
        described_class.canonicalize('not-a-valid-url')
      }.to raise_error(UrlCanonicaliser::InvalidUrlError)
    end

    it 'raises InvalidUrlError for non-HTTP(S) URLs' do
      expect {
        described_class.canonicalize('ftp://example.com/file')
      }.to raise_error(UrlCanonicaliser::InvalidUrlError)
    end

    it 'raises InvalidUrlError for URLs without host' do
      expect {
        described_class.canonicalize('http:///path')
      }.to raise_error(UrlCanonicaliser::InvalidUrlError)
    end

    context 'with HTML content containing canonical link' do
      let(:html) do
        '<html><head><link rel="canonical" href="https://example.com/canonical-path"></head><body></body></html>'
      end

      it 'uses canonical link from HTML' do
        result = described_class.canonicalize('https://example.com/original?utm_source=test', html_content: html)
        expect(result).to eq('https://example.com/canonical-path')
      end

      it 'handles relative canonical links' do
        html = '<html><head><link rel="canonical" href="/canonical-path"></head></html>'
        result = described_class.canonicalize('https://example.com/original', html_content: html)
        expect(result).to eq('https://example.com/canonical-path')
      end
    end

    context 'without HTML content' do
      it 'uses original URL' do
        result = described_class.canonicalize('https://example.com/article')
        expect(result).to eq('https://example.com/article')
      end
    end
  end
end
