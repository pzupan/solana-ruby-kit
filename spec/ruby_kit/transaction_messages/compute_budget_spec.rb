# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::TransactionMessages do
  let(:fee_payer) { RubyKit::Addresses::Address.new('So11111111111111111111111111111111111111112') }
  let(:blockhash_constraint) do
    RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
      blockhash: '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi',
      last_valid_block_height: 200
    )
  end

  let(:base_message) do
    RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
      .then { |m| RubyKit::TransactionMessages.set_fee_payer(fee_payer, m) }
      .then { |m| RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, m) }
  end

  describe '#get_transaction_message_compute_unit_limit' do
    it 'returns nil when no SetComputeUnitLimit instruction is present' do
      expect(described_class.get_transaction_message_compute_unit_limit(base_message)).to be_nil
    end

    it 'returns the limit after it is set' do
      msg = described_class.set_transaction_message_compute_unit_limit(200_000, base_message)
      expect(described_class.get_transaction_message_compute_unit_limit(msg)).to eq(200_000)
    end
  end

  describe '#set_transaction_message_compute_unit_limit' do
    it 'appends a SetComputeUnitLimit instruction when none exists' do
      msg = described_class.set_transaction_message_compute_unit_limit(300_000, base_message)
      cu_ix = msg.instructions.find { |i| described_class.set_compute_unit_limit_instruction?(i) }
      expect(cu_ix).not_to be_nil
      expect(described_class.get_transaction_message_compute_unit_limit(msg)).to eq(300_000)
    end

    it 'replaces an existing SetComputeUnitLimit instruction' do
      msg1 = described_class.set_transaction_message_compute_unit_limit(100_000, base_message)
      msg2 = described_class.set_transaction_message_compute_unit_limit(400_000, msg1)

      cu_instructions = msg2.instructions.select { |i| described_class.set_compute_unit_limit_instruction?(i) }
      expect(cu_instructions.size).to eq(1)
      expect(described_class.get_transaction_message_compute_unit_limit(msg2)).to eq(400_000)
    end

    it 'returns the same message object when the limit is already set to the same value' do
      msg1 = described_class.set_transaction_message_compute_unit_limit(200_000, base_message)
      msg2 = described_class.set_transaction_message_compute_unit_limit(200_000, msg1)
      expect(msg2).to equal(msg1)
    end
  end

  describe '#get_transaction_message_loaded_accounts_data_size_limit' do
    it 'returns nil when no SetLoadedAccountsDataSizeLimit instruction is present' do
      expect(described_class.get_transaction_message_loaded_accounts_data_size_limit(base_message)).to be_nil
    end

    it 'returns the limit after it is set' do
      msg = described_class.set_transaction_message_loaded_accounts_data_size_limit(1_024, base_message)
      expect(described_class.get_transaction_message_loaded_accounts_data_size_limit(msg)).to eq(1_024)
    end
  end

  describe '#set_transaction_message_loaded_accounts_data_size_limit' do
    it 'appends a SetLoadedAccountsDataSizeLimit instruction when none exists' do
      msg = described_class.set_transaction_message_loaded_accounts_data_size_limit(2_048, base_message)
      lads_ix = msg.instructions.find { |i| described_class.set_loaded_accounts_data_size_limit_instruction?(i) }
      expect(lads_ix).not_to be_nil
      expect(described_class.get_transaction_message_loaded_accounts_data_size_limit(msg)).to eq(2_048)
    end

    it 'replaces an existing SetLoadedAccountsDataSizeLimit instruction' do
      msg1 = described_class.set_transaction_message_loaded_accounts_data_size_limit(1_000, base_message)
      msg2 = described_class.set_transaction_message_loaded_accounts_data_size_limit(5_000, msg1)

      lads_instructions = msg2.instructions.select { |i| described_class.set_loaded_accounts_data_size_limit_instruction?(i) }
      expect(lads_instructions.size).to eq(1)
      expect(described_class.get_transaction_message_loaded_accounts_data_size_limit(msg2)).to eq(5_000)
    end
  end
end
