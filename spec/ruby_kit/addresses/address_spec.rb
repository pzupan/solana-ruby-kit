# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Addresses do
  # A real Solana address (32 bytes, base58-encoded)
  let(:valid_address_str) { '11111111111111111111111111111111' }
  # System program address — all zero bytes encode to 32 '1's
  let(:system_program)    { '11111111111111111111111111111111' }

  # A known valid address from Solana mainnet
  let(:sol_addr) { 'So11111111111111111111111111111111111111112' }

  describe '.address?' do
    it 'returns true for the system-program address (all-zero 32 bytes)' do
      expect(described_class.address?(system_program)).to be true
    end

    it 'returns true for a known mainnet address' do
      expect(described_class.address?(sol_addr)).to be true
    end

    it 'returns false when the string is too short' do
      expect(described_class.address?('abc')).to be false
    end

    it 'returns false when the string is too long (>44 chars)' do
      expect(described_class.address?('1' * 45)).to be false
    end

    it 'returns false for a string containing invalid base58 characters' do
      expect(described_class.address?('0' * 32)).to be false   # '0' not in alphabet
      expect(described_class.address?('O' * 32)).to be false   # 'O' not in alphabet
      expect(described_class.address?('I' * 32)).to be false   # 'I' not in alphabet
      expect(described_class.address?('l' * 32)).to be false   # 'l' not in alphabet
    end

    it 'returns false for an empty string' do
      expect(described_class.address?('')).to be false
    end
  end

  describe '.assert_address!' do
    it 'does not raise for a valid address' do
      expect { described_class.assert_address!(sol_addr) }.not_to raise_error
    end

    it 'raises SolanaError for a string that is too short' do
      expect { described_class.assert_address!('abc') }
        .to raise_error(RubyKit::SolanaError, /out of range/i)
    end

    it 'raises SolanaError for a string containing invalid base58 characters' do
      padded = 'O' + sol_addr[1..] # inject bad char, keep length valid
      expect { described_class.assert_address!(padded) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.address' do
    it 'returns an Address for a valid string' do
      addr = described_class.address(sol_addr)
      expect(addr).to be_a(RubyKit::Addresses::Address)
      expect(addr.value).to eq(sol_addr)
      expect(addr.to_s).to eq(sol_addr)
    end

    it 'raises SolanaError for an invalid string' do
      expect { described_class.address('not_valid!!!') }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe 'encode / decode round-trip' do
    it 'round-trips 32 random bytes through encode → Address → decode' do
      original_bytes = RbNaCl::Random.random_bytes(32)
      encoded        = described_class.encode_address(original_bytes)
      addr           = described_class.address(encoded)
      decoded        = described_class.decode_address(addr)

      expect(decoded).to eq(original_bytes.b)
    end

    it 'encodes all-zero bytes as 32 ones (system program)' do
      zero_bytes = "\x00" * 32
      expect(described_class.encode_address(zero_bytes)).to eq(system_program)
    end

    it 'raises SolanaError when encoding fewer than 32 bytes' do
      expect { described_class.encode_address("\x00" * 31) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.address_comparator' do
    it 'returns a callable that sorts Address values lexicographically' do
      addrs = [sol_addr, system_program].map { |s| described_class.address(s) }
      cmp   = described_class.address_comparator

      sorted = addrs.sort { |a, b| cmp.call(a, b) }
      expect(sorted.map(&:value)).to eq([system_program, sol_addr].sort)
    end
  end
end
