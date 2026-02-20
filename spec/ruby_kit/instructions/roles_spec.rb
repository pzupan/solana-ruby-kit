# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Instructions::AccountRole do
  describe 'constants' do
    it 'defines the four role values using bitflags' do
      expect(described_class::READONLY).to        eq(0b00)
      expect(described_class::WRITABLE).to        eq(0b01)
      expect(described_class::READONLY_SIGNER).to eq(0b10)
      expect(described_class::WRITABLE_SIGNER).to eq(0b11)
    end
  end

  describe '.signer_role?' do
    it 'returns true for signer roles' do
      expect(described_class.signer_role?(described_class::READONLY_SIGNER)).to be true
      expect(described_class.signer_role?(described_class::WRITABLE_SIGNER)).to be true
    end

    it 'returns false for non-signer roles' do
      expect(described_class.signer_role?(described_class::READONLY)).to be false
      expect(described_class.signer_role?(described_class::WRITABLE)).to be false
    end
  end

  describe '.writable_role?' do
    it 'returns true for writable roles' do
      expect(described_class.writable_role?(described_class::WRITABLE)).to be true
      expect(described_class.writable_role?(described_class::WRITABLE_SIGNER)).to be true
    end

    it 'returns false for read-only roles' do
      expect(described_class.writable_role?(described_class::READONLY)).to be false
      expect(described_class.writable_role?(described_class::READONLY_SIGNER)).to be false
    end
  end

  describe '.merge' do
    it 'returns WRITABLE_SIGNER when merging WRITABLE and READONLY_SIGNER' do
      result = described_class.merge(described_class::WRITABLE, described_class::READONLY_SIGNER)
      expect(result).to eq(described_class::WRITABLE_SIGNER)
    end

    it 'is idempotent when merging identical roles' do
      expect(described_class.merge(described_class::READONLY, described_class::READONLY)).to eq(described_class::READONLY)
    end
  end

  describe '.downgrade_to_non_signer / .downgrade_to_readonly' do
    it 'removes signer bit' do
      expect(described_class.downgrade_to_non_signer(described_class::WRITABLE_SIGNER)).to eq(described_class::WRITABLE)
      expect(described_class.downgrade_to_non_signer(described_class::READONLY_SIGNER)).to eq(described_class::READONLY)
    end

    it 'removes writable bit' do
      expect(described_class.downgrade_to_readonly(described_class::WRITABLE_SIGNER)).to eq(described_class::READONLY_SIGNER)
      expect(described_class.downgrade_to_readonly(described_class::WRITABLE)).to eq(described_class::READONLY)
    end
  end

  describe '.upgrade_to_signer / .upgrade_to_writable' do
    it 'adds signer bit' do
      expect(described_class.upgrade_to_signer(described_class::READONLY)).to eq(described_class::READONLY_SIGNER)
      expect(described_class.upgrade_to_signer(described_class::WRITABLE)).to eq(described_class::WRITABLE_SIGNER)
    end

    it 'adds writable bit' do
      expect(described_class.upgrade_to_writable(described_class::READONLY)).to eq(described_class::WRITABLE)
      expect(described_class.upgrade_to_writable(described_class::READONLY_SIGNER)).to eq(described_class::WRITABLE_SIGNER)
    end
  end
end
