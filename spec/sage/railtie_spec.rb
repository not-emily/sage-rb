# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Rails integration" do
  describe "conditional loading" do
    it "does not load railtie when Rails is not defined" do
      expect(defined?(Sage::Railtie)).to be_nil
    end

    it "does not error when requiring sage without Rails" do
      expect { require "sage" }.not_to raise_error
    end
  end

  describe "initializer template" do
    let(:template_path) do
      File.expand_path("../../lib/generators/sage/templates/initializer.rb.tt", __dir__)
    end

    it "exists" do
      expect(File.exist?(template_path)).to be true
    end

    it "is valid Ruby" do
      content = File.read(template_path)
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end

    it "contains provider examples" do
      content = File.read(template_path)
      expect(content).to include(":openai")
      expect(content).to include(":anthropic")
      expect(content).to include(":ollama")
    end

    it "contains profile examples" do
      content = File.read(template_path)
      expect(content).to include("config.profile")
      expect(content).to include("config.default_profile")
    end

    it "has all config lines commented out" do
      content = File.read(template_path)
      config_lines = content.lines.select { |l| l.include?("config.") }
      config_lines.each do |line|
        expect(line.strip).to start_with("#"), "Expected line to be commented: #{line.strip}"
      end
    end
  end
end
