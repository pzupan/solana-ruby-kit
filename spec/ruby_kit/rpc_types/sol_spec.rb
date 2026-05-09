# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Solana::Ruby::Kit::RpcTypes do
  include described_class

  describe '#sol' do
    it 'parses whole SOL amounts' do
      s = sol('1')
      expect(s.raw).to eq(1_000_000_000)
    end

    it 'parses fractional SOL amounts' do
      s = sol('1.5')
      expect(s.raw).to eq(1_500_000_000)
    end

    it 'parses one lamport' do
      s = sol('0.000000001')
      expect(s.raw).to eq(1)
    end

    it 'raises on more than 9 fractional digits (strict mode)' do
      expect { sol('1.1234567891') }
        .to raise_error(Solana::Ruby::Kit::SolanaError, /fractional/i)
    end

    it 'raises on negative values' do
      expect { sol('-1') }
        .to raise_error(Solana::Ruby::Kit::SolanaError)
    end
  end

  describe 'Sol#to_s' do
    it 'formats without trailing zeros' do
      expect(sol('1.5').to_s).to eq('1.5')
    end

    it 'formats whole amounts without decimal point' do
      expect(sol('2').to_s).to eq('2')
    end

    it 'formats small amounts correctly' do
      expect(sol('0.000000001').to_s).to eq('0.000000001')
    end
  end

  describe '#sol_to_lamports' do
    it 'returns the raw integer' do
      expect(sol_to_lamports(sol('1.5'))).to eq(1_500_000_000)
    end
  end

  describe '#lamports_to_sol' do
    it 'wraps a lamport integer as Sol' do
      s = lamports_to_sol(1_500_000_000)
      expect(s).to be_a(Solana::Ruby::Kit::RpcTypes::Sol)
      expect(s.raw).to eq(1_500_000_000)
    end

    it 'round-trips with sol_to_lamports' do
      original = sol('3.14')
      expect(lamports_to_sol(sol_to_lamports(original))).to eq(original)
    end
  end
end
