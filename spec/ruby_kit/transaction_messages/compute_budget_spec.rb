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

  # ── Resource limit validation ──────────────────────────────────────────────

  describe '#assert_is_valid_compute_unit_limit' do
    it 'accepts zero and the maximum limit' do
      expect { described_class.assert_is_valid_compute_unit_limit(0) }.not_to raise_error
      expect {
        described_class.assert_is_valid_compute_unit_limit(RubyKit::TransactionMessages::MAX_COMPUTE_UNIT_LIMIT)
      }.not_to raise_error
    end

    it 'raises when the limit exceeds the maximum' do
      over = RubyKit::TransactionMessages::MAX_COMPUTE_UNIT_LIMIT + 1

      expect { described_class.assert_is_valid_compute_unit_limit(over) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__COMPUTE_UNIT_LIMIT_OUT_OF_RANGE)
          expect(e.context[:compute_unit_limit]).to eq(over)
          expect(e.context[:max_compute_unit_limit]).to eq(RubyKit::TransactionMessages::MAX_COMPUTE_UNIT_LIMIT)
        }
    end

    it 'raises when the limit is negative' do
      expect { described_class.assert_is_valid_compute_unit_limit(-1) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__COMPUTE_UNIT_LIMIT_OUT_OF_RANGE)
        }
    end

    it 'raises when the limit is not an integer' do
      [1.5, 200_000.7, Float::INFINITY, Float::NAN, nil].each do |limit|
        expect { described_class.assert_is_valid_compute_unit_limit(limit) }
          .to raise_error(RubyKit::SolanaError) { |e|
            expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__COMPUTE_UNIT_LIMIT_OUT_OF_RANGE)
          }
      end
    end
  end

  describe '#assert_is_valid_heap_size' do
    it 'accepts the minimum, the maximum, and whole KiB in between' do
      [
        RubyKit::TransactionMessages::MIN_HEAP_SIZE,
        RubyKit::TransactionMessages::MAX_HEAP_SIZE,
        64 * 1024
      ].each do |size|
        expect { described_class.assert_is_valid_heap_size(size) }.not_to raise_error
      end
    end

    it 'raises when the size is out of range' do
      [
        RubyKit::TransactionMessages::MIN_HEAP_SIZE - 1024,
        RubyKit::TransactionMessages::MAX_HEAP_SIZE + 1024,
        0
      ].each do |size|
        expect { described_class.assert_is_valid_heap_size(size) }
          .to raise_error(RubyKit::SolanaError) { |e|
            expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__INVALID_HEAP_SIZE)
          }
      end
    end

    it 'raises when the size is not a whole number of KiB' do
      expect { described_class.assert_is_valid_heap_size(33_000) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__INVALID_HEAP_SIZE)
          expect(e.context[:heap_size]).to eq(33_000)
          expect(e.context[:multiple_of]).to eq(RubyKit::TransactionMessages::HEAP_SIZE_MULTIPLE_OF)
          expect(e.context[:min_heap_size]).to eq(RubyKit::TransactionMessages::MIN_HEAP_SIZE)
          expect(e.context[:max_heap_size]).to eq(RubyKit::TransactionMessages::MAX_HEAP_SIZE)
        }
    end

    it 'raises when the size is not an integer' do
      expect { described_class.assert_is_valid_heap_size(32_768.5) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__INVALID_HEAP_SIZE)
        }
    end
  end

  describe '#set_transaction_message_compute_unit_limit validation' do
    it 'rejects a limit above the maximum before touching the message' do
      over = RubyKit::TransactionMessages::MAX_COMPUTE_UNIT_LIMIT + 1

      expect { described_class.set_transaction_message_compute_unit_limit(over, base_message) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__COMPUTE_UNIT_LIMIT_OUT_OF_RANGE)
        }
    end

    it 'rejects a negative limit' do
      expect { described_class.set_transaction_message_compute_unit_limit(-1, base_message) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__COMPUTE_UNIT_LIMIT_OUT_OF_RANGE)
        }
    end

    it 'accepts zero and the maximum limit' do
      [0, RubyKit::TransactionMessages::MAX_COMPUTE_UNIT_LIMIT].each do |limit|
        msg = described_class.set_transaction_message_compute_unit_limit(limit, base_message)
        expect(described_class.get_transaction_message_compute_unit_limit(msg)).to eq(limit)
      end
    end
  end
end
