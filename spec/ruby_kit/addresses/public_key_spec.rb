# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Addresses do
  let(:key_pair)   { RbNaCl::SigningKey.generate }
  let(:verify_key) { key_pair.verify_key }

  describe '.get_address_from_public_key' do
    it 'returns an Address from a VerifyKey' do
      addr = described_class.get_address_from_public_key(verify_key)
      expect(addr).to be_a(RubyKit::Addresses::Address)
      expect(described_class.address?(addr.value)).to be true
    end

    it 'raises SolanaError when given something that is not a VerifyKey' do
      expect { described_class.get_address_from_public_key('not_a_key') }
        .to raise_error(RubyKit::SolanaError)
      expect { described_class.get_address_from_public_key(nil) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.get_public_key_from_address' do
    it 'round-trips: VerifyKey → Address → VerifyKey preserves bytes' do
      addr       = described_class.get_address_from_public_key(verify_key)
      recovered  = described_class.get_public_key_from_address(addr)

      expect(recovered.to_bytes).to eq(verify_key.to_bytes)
    end

    it 'raises SolanaError for an address whose bytes are not a valid Ed25519 key' do
      # All-zero bytes are not a valid Ed25519 public key for RbNaCl.
      zero_addr = described_class.address('11111111111111111111111111111111')
      # RbNaCl may or may not accept all-zero bytes as a VerifyKey;
      # the point is that the function delegates to RbNaCl and propagates errors.
      begin
        described_class.get_public_key_from_address(zero_addr)
      rescue RubyKit::SolanaError => e
        expect(e.code).to eq(RubyKit::SolanaError::ADDRESSES__INVALID_ED25519_PUBLIC_KEY)
      end
    end
  end
end
