# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Options do
  describe '.some / .none / .some? / .none? / .option?' do
    it 'creates Some and None values' do
      s = described_class.some(42)
      n = described_class.none

      expect(s).to be_a(RubyKit::Options::Some)
      expect(n).to be_a(RubyKit::Options::None)
    end

    it 'some? and none? work correctly' do
      expect(described_class.some?(described_class.some('hi'))).to be true
      expect(described_class.none?(described_class.some('hi'))).to be false
      expect(described_class.some?(described_class.none)).to be false
      expect(described_class.none?(described_class.none)).to be true
    end

    it 'option? returns true for both Some and None' do
      expect(described_class.option?(described_class.some(1))).to be true
      expect(described_class.option?(described_class.none)).to be true
      expect(described_class.option?(42)).to be false
      expect(described_class.option?(nil)).to be false
    end

    it 'None is a singleton' do
      expect(described_class.none).to equal(described_class.none)
    end
  end

  describe '.unwrap_option' do
    it 'returns the value for Some' do
      expect(described_class.unwrap_option(described_class.some('hello'))).to eq('hello')
    end

    it 'returns nil for None with no fallback' do
      expect(described_class.unwrap_option(described_class.none)).to be_nil
    end

    it 'calls fallback for None' do
      result = described_class.unwrap_option(described_class.none, -> { 'default' })
      expect(result).to eq('default')
    end
  end

  describe '.wrap_nullable' do
    it 'wraps a non-nil value in Some' do
      opt = described_class.wrap_nullable(99)
      expect(described_class.some?(opt)).to be true
      expect(opt.value).to eq(99)
    end

    it 'returns None for nil' do
      expect(described_class.none?(described_class.wrap_nullable(nil))).to be true
    end
  end

  describe '.unwrap_option_recursively' do
    it 'recursively unwraps nested Some values' do
      nested = described_class.some(described_class.some('deep'))
      expect(described_class.unwrap_option_recursively(nested)).to eq('deep')
    end

    it 'replaces None with nil by default' do
      expect(described_class.unwrap_option_recursively(described_class.none)).to be_nil
    end

    it 'replaces None with fallback when provided' do
      result = described_class.unwrap_option_recursively(described_class.none, -> { 'fallback' })
      expect(result).to eq('fallback')
    end

    it 'recursively unwraps options inside hashes' do
      input  = { a: described_class.some(1), b: described_class.none }
      result = described_class.unwrap_option_recursively(input)
      expect(result).to eq({ a: 1, b: nil })
    end

    it 'recursively unwraps options inside arrays' do
      input  = [described_class.some(1), described_class.none, described_class.some(3)]
      result = described_class.unwrap_option_recursively(input)
      expect(result).to eq([1, nil, 3])
    end

    it 'passes primitives through unchanged' do
      expect(described_class.unwrap_option_recursively(42)).to eq(42)
      expect(described_class.unwrap_option_recursively('hello')).to eq('hello')
    end
  end
end
