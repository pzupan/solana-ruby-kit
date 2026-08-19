# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::InstructionPlans do
  let(:system_program) { RubyKit::Addresses.address('11111111111111111111111111111111') }

  let(:dummy_instruction) do
    RubyKit::Instructions::Instruction.new(
      program_address: system_program,
      accounts:        [],
      data:            ''
    )
  end

  # ── SingleInstructionPlan ──────────────────────────────────────────────────

  describe '.single_instruction_plan' do
    it 'wraps one instruction and has kind :single' do
      plan = described_class.single_instruction_plan(dummy_instruction)
      expect(plan).to be_a(described_class::SingleInstructionPlan)
      expect(plan.instruction).to eq(dummy_instruction)
      expect(plan.kind).to eq(:single)
    end
  end

  # ── SequentialInstructionPlan ──────────────────────────────────────────────

  describe '.sequential_instruction_plan' do
    it 'is divisible and has kind :sequential' do
      plan = described_class.sequential_instruction_plan([dummy_instruction])
      expect(plan).to be_a(described_class::SequentialInstructionPlan)
      expect(plan.divisible).to be true
      expect(plan.kind).to eq(:sequential)
      expect(plan.plans.length).to eq(1)
      expect(plan.plans.first).to be_a(described_class::SingleInstructionPlan)
    end

    it 'auto-wraps bare Instruction objects' do
      plan = described_class.sequential_instruction_plan([dummy_instruction, dummy_instruction])
      expect(plan.plans).to all(be_a(described_class::SingleInstructionPlan))
    end
  end

  describe '.non_divisible_sequential_instruction_plan' do
    it 'is not divisible' do
      plan = described_class.non_divisible_sequential_instruction_plan([dummy_instruction])
      expect(plan.divisible).to be false
    end
  end

  # ── ParallelInstructionPlan ────────────────────────────────────────────────

  describe '.parallel_instruction_plan' do
    it 'holds sub-plans and has kind :parallel' do
      plan = described_class.parallel_instruction_plan([dummy_instruction, dummy_instruction])
      expect(plan).to be_a(described_class::ParallelInstructionPlan)
      expect(plan.plans.length).to eq(2)
      expect(plan.kind).to eq(:parallel)
    end

    it 'auto-wraps bare Instruction objects' do
      plan = described_class.parallel_instruction_plan([dummy_instruction])
      expect(plan.plans.first).to be_a(described_class::SingleInstructionPlan)
    end
  end

  # ── flatten_instruction_plan ───────────────────────────────────────────────

  describe '.flatten_instruction_plan' do
    it 'extracts all instructions from a nested plan' do
      a    = described_class.single_instruction_plan(dummy_instruction)
      b    = described_class.single_instruction_plan(dummy_instruction)
      seq  = described_class.sequential_instruction_plan([a, b])
      par  = described_class.parallel_instruction_plan([seq])
      root = described_class.sequential_instruction_plan([par])

      flat = described_class.flatten_instruction_plan(root)
      expect(flat.length).to eq(2)
      expect(flat).to all(be_a(RubyKit::Instructions::Instruction))
    end

    it 'raises for MessagePackerInstructionPlan (dynamically generated)' do
      packer_plan = described_class.get_message_packer_instruction_plan_from_instructions([])
      expect { described_class.flatten_instruction_plan(packer_plan) }.to raise_error(ArgumentError)
    end
  end

  # ── TransactionPlan types ──────────────────────────────────────────────────

  describe 'TransactionPlan helpers' do
    let(:fee_payer_kp) { RbNaCl::SigningKey.generate }
    let(:fee_payer) { RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key) }
    let(:blockhash_constraint) do
      RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
        blockhash: '4PZNQ5MjgFMRSAEKFbMrgCkKAJAV2VEDiJFy1JoqyN3f',
        last_valid_block_height: 9999
      )
    end
    let(:message) do
      RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
        .then { |m| RubyKit::TransactionMessages.set_fee_payer(fee_payer, m) }
        .then { |m| RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, m) }
    end

    describe '.single_transaction_plan' do
      it 'wraps a message and has kind :single' do
        plan = described_class.single_transaction_plan(message)
        expect(plan).to be_a(described_class::SingleTransactionPlan)
        expect(plan.kind).to eq(:single)
        expect(plan.message).to eq(message)
      end
    end

    describe '.sequential_transaction_plan' do
      it 'is divisible and auto-wraps messages' do
        plan = described_class.sequential_transaction_plan([message])
        expect(plan.divisible).to be true
        expect(plan.plans.first).to be_a(described_class::SingleTransactionPlan)
      end
    end

    describe '.non_divisible_sequential_transaction_plan' do
      it 'is not divisible' do
        plan = described_class.non_divisible_sequential_transaction_plan([message])
        expect(plan.divisible).to be false
      end
    end

    describe '.parallel_transaction_plan' do
      it 'holds plans and has kind :parallel' do
        plan = described_class.parallel_transaction_plan([message, message])
        expect(plan.kind).to eq(:parallel)
        expect(plan.plans.length).to eq(2)
      end
    end

    describe '.get_all_single_transaction_plans' do
      it 'collects all leaves' do
        nested = described_class.sequential_transaction_plan([
          described_class.parallel_transaction_plan([message, message]),
          message
        ])
        leaves = described_class.get_all_single_transaction_plans(nested)
        expect(leaves.length).to eq(3)
        expect(leaves).to all(be_a(described_class::SingleTransactionPlan))
      end
    end
  end

  # ── TransactionPlanResult helpers ──────────────────────────────────────────

  describe 'TransactionPlanResult helpers' do
    let(:fee_payer_kp) { RbNaCl::SigningKey.generate }
    let(:fee_payer) { RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key) }
    let(:blockhash_constraint) do
      RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
        blockhash: '4PZNQ5MjgFMRSAEKFbMrgCkKAJAV2VEDiJFy1JoqyN3f',
        last_valid_block_height: 9999
      )
    end
    let(:message) do
      RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
        .then { |m| RubyKit::TransactionMessages.set_fee_payer(fee_payer, m) }
        .then { |m| RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, m) }
    end
    let(:transaction) { RubyKit::Transactions.compile_transaction_message(message) }

    it 'creates a successful single result' do
      result = described_class.successful_single_transaction_plan_result(message, transaction)
      expect(result.kind).to eq(:single)
      expect(result.status.kind).to eq(:successful)
      expect(result.status.transaction).to eq(transaction)
      expect(result.status.context).to eq({})
    end

    it 'creates a failed single result' do
      error  = RubyKit::SolanaError.new(RubyKit::SolanaError::TRANSACTIONS__BLOCKHASH_NOT_FOUND)
      result = described_class.failed_single_transaction_plan_result(message, error)
      expect(result.status.kind).to eq(:failed)
      expect(result.status.error).to eq(error)
    end

    it 'creates a canceled single result' do
      result = described_class.canceled_single_transaction_plan_result(message)
      expect(result.status.kind).to eq(:canceled)
    end

    it 'creates sequential and parallel result containers' do
      r1  = described_class.canceled_single_transaction_plan_result(message)
      r2  = described_class.canceled_single_transaction_plan_result(message)
      seq = described_class.sequential_transaction_plan_result([r1, r2])
      par = described_class.parallel_transaction_plan_result([r1, r2])

      expect(seq.kind).to eq(:sequential)
      expect(seq.divisible).to be true
      expect(par.kind).to eq(:parallel)
      expect(par.plans.length).to eq(2)
    end
  end

  # ── create_transaction_plan_executor ──────────────────────────────────────

  describe '.create_transaction_plan_executor' do
    let(:fee_payer_kp) { RbNaCl::SigningKey.generate }
    let(:fee_payer) { RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key) }
    let(:blockhash_constraint) do
      RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
        blockhash: '4PZNQ5MjgFMRSAEKFbMrgCkKAJAV2VEDiJFy1JoqyN3f',
        last_valid_block_height: 9999
      )
    end
    let(:message) do
      RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
        .then { |m| RubyKit::TransactionMessages.set_fee_payer(fee_payer, m) }
        .then { |m| RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, m) }
    end

    it 'executes a single-message plan and returns a successful result' do
      tx = RubyKit::Transactions.compile_transaction_message(message)
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(_msg) { { transaction: tx } }
      )
      plan   = described_class.single_transaction_plan(message)
      result = executor.call(plan)

      expect(result.kind).to eq(:single)
      expect(result.status.kind).to eq(:successful)
      expect(result.status.transaction).to eq(tx)
    end

    it 'marks remaining plans as canceled after a failure' do
      tx       = RubyKit::Transactions.compile_transaction_message(message)
      call_count = 0
      executor   = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(_msg) {
          call_count += 1
          raise RubyKit::SolanaError.new(RubyKit::SolanaError::TRANSACTIONS__BLOCKHASH_NOT_FOUND) if call_count == 1
          { transaction: tx }
        }
      )

      plan = described_class.sequential_transaction_plan([
        described_class.single_transaction_plan(message),
        described_class.single_transaction_plan(message)
      ])

      expect { executor.call(plan) }.to raise_error(RubyKit::SolanaError)
    end

    it 'reports the context the callback returns' do
      tx       = RubyKit::Transactions.compile_transaction_message(message)
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(_context, _msg) { { transaction: tx, signature: 'sig' } }
      )
      result = executor.call(described_class.single_transaction_plan(message))

      expect(result.status.context).to eq({ transaction: tx, signature: 'sig' })
      expect(result.status.transaction).to eq(tx)
    end

    it 'merges the returned context over the stored one, the returned value winning' do
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(context, _msg) {
          context[:started_at] = 1
          context[:signature]  = 'stored'
          { signature: 'returned' }
        }
      )
      result = executor.call(described_class.single_transaction_plan(message))

      expect(result.status.context).to eq({ started_at: 1, signature: 'returned' })
    end

    it 'preserves the context accumulated before a failure' do
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(context, _msg) {
          context[:started_at] = 42
          raise RubyKit::SolanaError.new(RubyKit::SolanaError::TRANSACTIONS__BLOCKHASH_NOT_FOUND)
        }
      )
      plan = described_class.single_transaction_plan(message)

      error = nil
      begin
        executor.call(plan)
      rescue RubyKit::SolanaError => e
        error = e
      end

      failed = error.transaction_plan_result
      expect(failed.status.kind).to eq(:failed)
      expect(failed.status.context).to eq({ started_at: 42 })
    end

    it 'gives each single plan its own context and carries one on canceled results' do
      contexts = []
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(context, _msg) {
          contexts << context
          context[:seen] = contexts.length
          raise RubyKit::SolanaError.new(RubyKit::SolanaError::TRANSACTIONS__BLOCKHASH_NOT_FOUND)
        }
      )
      plan = described_class.sequential_transaction_plan([
        described_class.single_transaction_plan(message),
        described_class.single_transaction_plan(message)
      ])

      error = nil
      begin
        executor.call(plan)
      rescue RubyKit::SolanaError => e
        error = e
      end

      results = error.transaction_plan_result.plans
      expect(results[0].status.kind).to eq(:failed)
      expect(results[0].status.context).to eq({ seen: 1 })
      # The second plan never ran, so it is canceled with the empty context it was given.
      expect(results[1].status.kind).to eq(:canceled)
      expect(results[1].status.context).to eq({})
      expect(contexts.length).to eq(1)
    end

    it 'still accepts the legacy one-argument callback shape' do
      tx       = RubyKit::Transactions.compile_transaction_message(message)
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(_msg) { { transaction: tx, context: { note: 'hi' } } }
      )
      result = executor.call(described_class.single_transaction_plan(message))

      expect(result.status.transaction).to eq(tx)
      expect(result.status.context).to eq({ note: 'hi', transaction: tx })
    end

    it 'freezes the context reported on a result' do
      executor = described_class.create_transaction_plan_executor(
        execute_transaction_message: ->(context, _msg) {
          context[:a] = 1
          {}
        }
      )
      result = executor.call(described_class.single_transaction_plan(message))

      expect(result.status.context).to be_frozen
    end
  end
end
