# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Programs::StakeProgram do
  # Fixture addresses — valid base58-encoded 32-byte pubkeys.
  let(:from_str)          { '6ZRCB7AAqGre6c72PRz3MHLC73VMYvJ8bi9KHf1HFpNk' }
  let(:stake_account_str) { 'DRpbCBMxVnDK7maPM5tGv6MvB3v1sRMC86PZ8okm21hy' }
  let(:authorized_str)    { 'So11111111111111111111111111111111111111112' }
  let(:vote_account_str)  { '3DVYeFioMkc5eFQfpHJ1cAT3RGNR8LTWBB27uRr4BPUS' }

  let(:from)          { RubyKit::Addresses::Address.new(from_str) }
  let(:stake_account) { RubyKit::Addresses::Address.new(stake_account_str) }
  let(:authorized)    { RubyKit::Addresses::Address.new(authorized_str) }
  let(:vote_account)  { RubyKit::Addresses::Address.new(vote_account_str) }

  let(:lamports) { 2_282_880 }

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------
  describe 'PROGRAM_ID' do
    it 'is the canonical stake program address' do
      expect(described_class::PROGRAM_ID.value).to eq('Stake11111111111111111111111111111111111111111')
    end
  end

  describe 'STAKE_CONFIG_ID' do
    it 'is the canonical stake config address' do
      expect(described_class::STAKE_CONFIG_ID.value).to eq('StakeConfig11111111111111111111111111111111')
    end
  end

  describe 'STAKE_ACCOUNT_SPACE' do
    it 'is 200 bytes' do
      expect(described_class::STAKE_ACCOUNT_SPACE).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # create_account_instructions
  # ---------------------------------------------------------------------------
  describe '.create_account_instructions' do
    subject(:instructions) do
      described_class.create_account_instructions(
        from:          from,
        stake_account: stake_account,
        authorized:    authorized,
        lamports:      lamports
      )
    end

    it 'returns an array of exactly 2 instructions' do
      expect(instructions).to be_an(Array)
      expect(instructions.length).to eq(2)
      expect(instructions).to all(be_a(RubyKit::Instructions::Instruction))
    end

    # -------------------------------------------------------------------------
    # Instruction 0 — System Program createAccount
    # -------------------------------------------------------------------------
    describe 'instruction 0 (System Program createAccount)' do
      subject(:ix) { instructions[0] }

      it 'targets the System Program' do
        expect(ix.program_address.value).to eq('11111111111111111111111111111111')
      end

      it 'has exactly 2 accounts' do
        expect(ix.accounts&.length).to eq(2)
      end

      it 'account 0 (from) is writable signer' do
        acct = ix.accounts&.fetch(0)
        expect(acct&.address&.value).to eq(from_str)
        expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::WRITABLE_SIGNER)
      end

      it 'account 1 (stake_account) is writable signer' do
        acct = ix.accounts&.fetch(1)
        expect(acct&.address&.value).to eq(stake_account_str)
        expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::WRITABLE_SIGNER)
      end

      it 'data is 52 bytes in binary encoding' do
        expect(ix.data&.bytesize).to eq(52)
        expect(ix.data&.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it 'data discriminant is 0 (CREATE_ACCOUNT)' do
        discriminant = ix.data&.unpack1('V')
        expect(discriminant).to eq(0)
      end

      it 'data encodes the correct lamports' do
        fields = ix.data&.unpack('VQ<Q<a32')
        expect(fields&.fetch(1)).to eq(lamports)
      end

      it 'data encodes STAKE_ACCOUNT_SPACE (200) as the account size' do
        fields = ix.data&.unpack('VQ<Q<a32')
        expect(fields&.fetch(2)).to eq(200)
      end

      it 'data encodes the Stake Program ID as the owner' do
        fields = ix.data&.unpack('VQ<Q<a32')
        owner_bytes = fields&.fetch(3)
        # Base58.decode may return more bytes than 32 for this address, so normalize
        # both sides through the same a32 pack/truncate that the implementation uses.
        raw = RubyKit::Encoding::Base58.decode('Stake11111111111111111111111111111111111111111')
        expected_bytes = [raw].pack('a32').b
        expect(owner_bytes).to eq(expected_bytes)
      end
    end

    # -------------------------------------------------------------------------
    # Instruction 1 — Stake Program Initialize
    # -------------------------------------------------------------------------
    describe 'instruction 1 (Stake Program Initialize)' do
      subject(:ix) { instructions[1] }

      it 'targets the Stake Program' do
        expect(ix.program_address.value).to eq('Stake11111111111111111111111111111111111111111')
      end

      it 'has exactly 2 accounts' do
        expect(ix.accounts&.length).to eq(2)
      end

      it 'account 0 (stake_account) is writable, not signer' do
        acct = ix.accounts&.fetch(0)
        expect(acct&.address&.value).to eq(stake_account_str)
        expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::WRITABLE)
      end

      it 'account 1 (sysvar rent) is readonly, not signer' do
        acct = ix.accounts&.fetch(1)
        expect(acct&.address&.value).to eq('SysvarRent111111111111111111111111111111111')
        expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY)
      end

      it 'data is 116 bytes in binary encoding' do
        expect(ix.data&.bytesize).to eq(116)
        expect(ix.data&.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it 'data discriminant is 0 (Initialize)' do
        discriminant = ix.data&.unpack1('V')
        expect(discriminant).to eq(0)
      end

      it 'data encodes authorized pubkey as staker' do
        fields = ix.data&.unpack('Va32a32q<Q<a32')
        staker_bytes = fields&.fetch(1)
        expected_bytes = RubyKit::Encoding::Base58.decode(authorized_str)
        expect(staker_bytes).to eq(expected_bytes)
      end

      it 'data encodes authorized pubkey as withdrawer' do
        fields = ix.data&.unpack('Va32a32q<Q<a32')
        withdrawer_bytes = fields&.fetch(2)
        expected_bytes = RubyKit::Encoding::Base58.decode(authorized_str)
        expect(withdrawer_bytes).to eq(expected_bytes)
      end

      it 'data encodes lockup unix_timestamp as 0' do
        fields = ix.data&.unpack('Va32a32q<Q<a32')
        expect(fields&.fetch(3)).to eq(0)
      end

      it 'data encodes lockup epoch as 0' do
        fields = ix.data&.unpack('Va32a32q<Q<a32')
        expect(fields&.fetch(4)).to eq(0)
      end

      it 'data encodes lockup custodian as zero pubkey' do
        fields = ix.data&.unpack('Va32a32q<Q<a32')
        custodian_bytes = fields&.fetch(5)
        expect(custodian_bytes).to eq(("\x00" * 32).b)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # delegate_instruction
  # ---------------------------------------------------------------------------
  describe '.delegate_instruction' do
    subject(:ix) do
      described_class.delegate_instruction(
        stake_account: stake_account,
        vote_account:  vote_account,
        authorized:    authorized
      )
    end

    it 'returns a single Instruction' do
      expect(ix).to be_a(RubyKit::Instructions::Instruction)
    end

    it 'targets the Stake Program' do
      expect(ix.program_address.value).to eq('Stake11111111111111111111111111111111111111111')
    end

    it 'has exactly 6 accounts' do
      expect(ix.accounts&.length).to eq(6)
    end

    it 'account 0 (stake_account) is writable, not signer' do
      acct = ix.accounts&.fetch(0)
      expect(acct&.address&.value).to eq(stake_account_str)
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::WRITABLE)
    end

    it 'account 1 (vote_account) is readonly, not signer' do
      acct = ix.accounts&.fetch(1)
      expect(acct&.address&.value).to eq(vote_account_str)
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY)
    end

    it 'account 2 is the clock sysvar (readonly)' do
      acct = ix.accounts&.fetch(2)
      expect(acct&.address&.value).to eq('SysvarC1ock11111111111111111111111111111111')
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY)
    end

    it 'account 3 is the stake history sysvar (readonly)' do
      acct = ix.accounts&.fetch(3)
      expect(acct&.address&.value).to eq('SysvarStakeHistory1111111111111111111111111')
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY)
    end

    it 'account 4 is the stake config account (readonly)' do
      acct = ix.accounts&.fetch(4)
      expect(acct&.address&.value).to eq('StakeConfig11111111111111111111111111111111')
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY)
    end

    it 'account 5 (authorized) is readonly signer' do
      acct = ix.accounts&.fetch(5)
      expect(acct&.address&.value).to eq(authorized_str)
      expect(acct&.role).to eq(RubyKit::Instructions::AccountRole::READONLY_SIGNER)
    end

    it 'data is 4 bytes in binary encoding' do
      expect(ix.data&.bytesize).to eq(4)
      expect(ix.data&.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it 'data discriminant is 2 (DelegateStake)' do
      discriminant = ix.data&.unpack1('V')
      expect(discriminant).to eq(2)
    end
  end
end
