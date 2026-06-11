# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::ResourceLimitEstimation do
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

  # ---------------------------------------------------------------------------
  # fill_transaction_message_provisory_resource_limits
  # ---------------------------------------------------------------------------
  describe '.fill_transaction_message_provisory_resource_limits' do
    it 'adds a provisory (0) compute unit limit when none is set' do
      result = described_class.fill_transaction_message_provisory_resource_limits(base_message)
      expect(RubyKit::TransactionMessages.get_transaction_message_compute_unit_limit(result)).to eq(0)
    end

    it 'leaves an existing compute unit limit untouched' do
      msg = RubyKit::TransactionMessages.set_transaction_message_compute_unit_limit(100_000, base_message)
      result = described_class.fill_transaction_message_provisory_resource_limits(msg)
      expect(RubyKit::TransactionMessages.get_transaction_message_compute_unit_limit(result)).to eq(100_000)
    end

    it 'does not add a loaded accounts data size limit for legacy transactions' do
      result = described_class.fill_transaction_message_provisory_resource_limits(base_message)
      expect(RubyKit::TransactionMessages.get_transaction_message_loaded_accounts_data_size_limit(result)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # estimate_resource_limits_factory
  # ---------------------------------------------------------------------------
  describe '.estimate_resource_limits_factory' do
    let(:rpc) { double('rpc') }

    it 'returns compute_unit_limit from simulation result' do
      sim_value = { 'err' => nil, 'unitsConsumed' => 42_000, 'loadedAccountsDataSize' => nil }
      allow(rpc).to receive(:simulate_transaction).and_return(
        double('ctx', value: sim_value)
      )

      estimator = described_class.estimate_resource_limits_factory(rpc: rpc)
      estimate  = estimator.call(base_message)
      expect(estimate[:compute_unit_limit]).to eq(42_000)
      expect(estimate.key?(:loaded_accounts_data_size_limit)).to be false
    end

    it 'includes loaded_accounts_data_size_limit when the RPC returns it' do
      sim_value = { 'err' => nil, 'unitsConsumed' => 10_000, 'loadedAccountsDataSize' => 8_192 }
      allow(rpc).to receive(:simulate_transaction).and_return(
        double('ctx', value: sim_value)
      )

      estimator = described_class.estimate_resource_limits_factory(rpc: rpc)
      estimate  = estimator.call(base_message)
      expect(estimate[:compute_unit_limit]).to              eq(10_000)
      expect(estimate[:loaded_accounts_data_size_limit]).to eq(8_192)
    end

    it 'raises FAILED_WHEN_SIMULATING_TO_ESTIMATE_RESOURCE_LIMITS when the tx fails' do
      sim_value = { 'err' => { 'InstructionError' => [0, 'Custom'] }, 'unitsConsumed' => 5_000, 'loadedAccountsDataSize' => nil }
      allow(rpc).to receive(:simulate_transaction).and_return(
        double('ctx', value: sim_value)
      )

      estimator = described_class.estimate_resource_limits_factory(rpc: rpc)
      expect { estimator.call(base_message) }.to raise_error(
        RubyKit::SolanaError,
        /estimate its resource limits/
      )
    end

    it 'raises FAILED_TO_ESTIMATE_COMPUTE_LIMIT on unexpected RPC errors' do
      allow(rpc).to receive(:simulate_transaction).and_raise(RuntimeError, 'network timeout')

      estimator = described_class.estimate_resource_limits_factory(rpc: rpc)
      expect { estimator.call(base_message) }.to raise_error(
        RubyKit::SolanaError
      ) do |e|
        expect(e.code).to eq(RubyKit::SolanaError::TRANSACTION__FAILED_TO_ESTIMATE_COMPUTE_LIMIT)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # estimate_and_set_resource_limits_factory
  # ---------------------------------------------------------------------------
  describe '.estimate_and_set_resource_limits_factory' do
    let(:estimate_fn) do
      ->(_msg, **_opts) { { compute_unit_limit: 75_000 } }
    end

    it 'sets the estimated compute unit limit on the message' do
      setter   = described_class.estimate_and_set_resource_limits_factory(estimate_fn)
      result   = setter.call(base_message)
      expect(RubyKit::TransactionMessages.get_transaction_message_compute_unit_limit(result)).to eq(75_000)
    end

    it 'skips estimation when the compute unit limit is already explicitly set' do
      msg    = RubyKit::TransactionMessages.set_transaction_message_compute_unit_limit(50_000, base_message)
      setter = described_class.estimate_and_set_resource_limits_factory(estimate_fn)
      result = setter.call(msg)
      expect(RubyKit::TransactionMessages.get_transaction_message_compute_unit_limit(result)).to eq(50_000)
    end

    it 'replaces a provisory (0) compute unit limit with the estimate' do
      msg    = RubyKit::TransactionMessages.set_transaction_message_compute_unit_limit(0, base_message)
      setter = described_class.estimate_and_set_resource_limits_factory(estimate_fn)
      result = setter.call(msg)
      expect(RubyKit::TransactionMessages.get_transaction_message_compute_unit_limit(result)).to eq(75_000)
    end
  end
end
