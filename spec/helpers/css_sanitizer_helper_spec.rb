# frozen_string_literal: true

require "rails_helper"

RSpec.describe CssSanitizerHelper, type: :helper do
  describe "#sanitize_css" do
    it "returns empty string for blank input" do
      expect(helper.sanitize_css(nil)).to eq("")
      expect(helper.sanitize_css("")).to eq("")
    end

    it "preserves valid CSS" do
      css = ".class { color: red; font-size: 16px; }"
      expect(helper.sanitize_css(css)).to eq(css)
    end

    it "removes javascript: URLs" do
      css = "background: url(javascript:alert(1));"
      result = helper.sanitize_css(css)
      expect(result).not_to include("javascript:")
    end

    it "removes expression() calls" do
      css = "width: expression(alert(1));"
      result = helper.sanitize_css(css)
      expect(result).not_to include("expression(")
    end

    it "removes @import statements" do
      css = "@import url('http://evil.com/hack.css');"
      result = helper.sanitize_css(css)
      expect(result).not_to include("@import")
    end

    it "removes behavior properties" do
      css = "behavior: url(http://evil.com/xss.htc);"
      result = helper.sanitize_css(css)
      expect(result).not_to include("behavior:")
    end

    it "removes script tags" do
      css = "</style><script>alert(1)</script><style>"
      result = helper.sanitize_css(css)
      expect(result).not_to include("<script")
      expect(result).not_to include("</script")
    end

    it "removes angle brackets" do
      css = "<script>alert(1)</script>"
      result = helper.sanitize_css(css)
      expect(result).not_to include("<")
      expect(result).not_to include(">")
    end

    it "removes event handlers" do
      css = "onload=alert(1)"
      result = helper.sanitize_css(css)
      expect(result).not_to match(/onload\s*=/)
    end

    it "returns html_safe string" do
      css = ".class { color: blue; }"
      expect(helper.sanitize_css(css)).to be_html_safe
    end
  end
end
