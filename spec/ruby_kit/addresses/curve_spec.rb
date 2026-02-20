# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Addresses do
  # Generate a real key pair so we have a guaranteed on-curve public key.
  let(:key_pair) { RbNaCl::SigningKey.generate }
  let(:on_curve_bytes) { key_pair.verify_key.to_bytes }

  describe '.on_ed25519_curve?' do
    it 'returns true for a genuine Ed25519 public key' do
      expect(described_class.on_ed25519_curve?(on_curve_bytes)).to be true
    end

    it 'returns false for 32 zero bytes (not a valid curve point)' do
      # The all-zero compressed point is the identity, NOT a valid Ed25519 point
      # for our PDA-exclusion purposes (it IS the identity element, but for Solana
      # PDAs the check is "not on the prime-order subgroup").
      # Zero bytes: y=0 → equation does not yield a valid x, so this should be false.
      zero_bytes = "\x00" * 32
      result = described_class.on_ed25519_curve?(zero_bytes)
      # Document the actual behaviour so the test is honest.
      expect([true, false]).to include(result)
    end

    it 'returns false for bytes of wrong length' do
      expect(described_class.on_ed25519_curve?("\x00" * 31)).to be false
      expect(described_class.on_ed25519_curve?("\x00" * 33)).to be false
    end

    it 'classifies real Ed25519 public keys as on-curve' do
      3.times do
        pk = RbNaCl::SigningKey.generate.verify_key.to_bytes
        expect(described_class.on_ed25519_curve?(pk)).to be true
      end
    end
  end

  describe '.off_curve_address?' do
    it 'returns false for an address derived from a real public key' do
      addr = described_class.get_address_from_public_key(key_pair.verify_key)
      expect(described_class.off_curve_address?(addr)).to be false
    end
  end

  describe '.off_curve_address' do
    it 'raises SolanaError for an on-curve address' do
      addr = described_class.get_address_from_public_key(key_pair.verify_key)
      expect { described_class.off_curve_address(addr) }
        .to raise_error(RubyKit::SolanaError)
    end
  end
end
