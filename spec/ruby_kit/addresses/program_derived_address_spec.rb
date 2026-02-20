# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Addresses do
  # System program: 11111111111111111111111111111111 (all-zero 32 bytes)
  let(:system_program) { described_class.address('11111111111111111111111111111111') }

  describe '.get_program_derived_address' do
    it 'returns a ProgramDerivedAddress with a bump in [0, 255]' do
      pda = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['test_seed']
      )

      expect(pda).to be_a(RubyKit::Addresses::ProgramDerivedAddress)
      expect(pda.bump).to be_between(0, 255)
      expect(pda.address).to be_a(RubyKit::Addresses::Address)
    end

    it 'produces a deterministic address for the same inputs' do
      pda1 = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['deterministic']
      )
      pda2 = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['deterministic']
      )

      expect(pda1.address.value).to eq(pda2.address.value)
      expect(pda1.bump).to eq(pda2.bump)
    end

    it 'produces a different PDA for different seeds' do
      pda1 = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['seed_a']
      )
      pda2 = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['seed_b']
      )

      expect(pda1.address.value).not_to eq(pda2.address.value)
    end

    it 'accepts binary seed arrays (Integer arrays)' do
      expect do
        described_class.get_program_derived_address(
          program_address: system_program,
          seeds:           [[0x01, 0x02, 0x03]]
        )
      end.not_to raise_error
    end

    it 'raises SolanaError when more than 16 seeds are supplied' do
      expect do
        described_class.get_program_derived_address(
          program_address: system_program,
          seeds:           Array.new(17, 'x')
        )
      end.to raise_error(RubyKit::SolanaError)
    end

    it 'raises SolanaError when a seed exceeds 32 bytes' do
      expect do
        described_class.get_program_derived_address(
          program_address: system_program,
          seeds:           ['a' * 33]
        )
      end.to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.create_address_with_seed' do
    let(:base_addr) { described_class.address('11111111111111111111111111111111') }

    it 'returns a valid Address' do
      result = described_class.create_address_with_seed(
        base_address:    base_addr,
        program_address: system_program,
        seed:            'my_seed'
      )
      expect(result).to be_a(RubyKit::Addresses::Address)
    end

    it 'is deterministic' do
      a = described_class.create_address_with_seed(
        base_address:    base_addr,
        program_address: system_program,
        seed:            'hello'
      )
      b = described_class.create_address_with_seed(
        base_address:    base_addr,
        program_address: system_program,
        seed:            'hello'
      )
      expect(a.value).to eq(b.value)
    end

    it 'raises SolanaError when seed exceeds 32 bytes' do
      expect do
        described_class.create_address_with_seed(
          base_address:    base_addr,
          program_address: system_program,
          seed:            'x' * 33
        )
      end.to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.program_derived_address?' do
    it 'returns true for a valid PDA struct' do
      pda = described_class.get_program_derived_address(
        program_address: system_program,
        seeds:           ['valid']
      )
      expect(described_class.program_derived_address?(pda)).to be true
    end

    it 'returns false for a non-PDA object' do
      expect(described_class.program_derived_address?('not_a_pda')).to be false
      expect(described_class.program_derived_address?(nil)).to be false
    end
  end
end
