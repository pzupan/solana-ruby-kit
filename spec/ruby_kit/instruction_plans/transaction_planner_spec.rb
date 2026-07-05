# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::InstructionPlans do
  let(:system_program) { RubyKit::Addresses.address('11111111111111111111111111111111') }
  let(:fee_payer_kp) { RbNaCl::SigningKey.generate }
  let(:fee_payer) { RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key) }
  let(:blockhash_constraint) do
    RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
      blockhash: '4PZNQ5MjgFMRSAEKFbMrgCkKAJAV2VEDiJFy1JoqyN3f',
      last_valid_block_height: 9999
    )
  end
  let(:create_transaction_message) do
    -> {
      RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
        .then { |m| RubyKit::TransactionMessages.set_fee_payer(fee_payer, m) }
        .then { |m| RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, m) }
    }
  end
  let(:dummy_instruction) do
    RubyKit::Instructions::Instruction.new(
      program_address: system_program,
      accounts:        [],
      data:            ''
    )
  end

  def instructions(count)
    Array.new(count) { dummy_instruction }
  end

  describe '.create_transaction_planner' do
    it 'packs instructions under the default 16-per-transaction cap into a single message' do
      planner = described_class.create_transaction_planner(create_transaction_message: create_transaction_message)
      plan    = planner.call(described_class.sequential_instruction_plan(instructions(16)))

      expect(plan.kind).to eq(:single)
      expect(plan.message.instructions.length).to eq(16)
    end

    it 'splits across transactions once the default 16-per-transaction cap is exceeded' do
      planner = described_class.create_transaction_planner(create_transaction_message: create_transaction_message)
      plan    = planner.call(described_class.sequential_instruction_plan(instructions(17)))

      expect(plan.kind).to eq(:sequential)
      expect(plan.plans.map { |p| p.message.instructions.length }).to eq([16, 1])
    end

    it 'honors a configured max_instructions_per_transaction' do
      planner = described_class.create_transaction_planner(
        create_transaction_message: create_transaction_message,
        max_instructions_per_transaction: 2
      )
      plan = planner.call(described_class.sequential_instruction_plan(instructions(5)))

      expect(plan.kind).to eq(:sequential)
      expect(plan.plans.map { |p| p.message.instructions.length }).to eq([2, 2, 1])
    end

    it 'lets a per-call max_instructions_per_transaction override the config default' do
      planner = described_class.create_transaction_planner(
        create_transaction_message: create_transaction_message,
        max_instructions_per_transaction: 2
      )
      plan = planner.call(
        described_class.sequential_instruction_plan(instructions(3)),
        max_instructions_per_transaction: 3
      )

      expect(plan.kind).to eq(:single)
      expect(plan.message.instructions.length).to eq(3)
    end

    it 'caps a message packer plan at the configured max_instructions_per_transaction' do
      planner = described_class.create_transaction_planner(
        create_transaction_message: create_transaction_message,
        max_instructions_per_transaction: 3
      )
      packer_plan = described_class.get_message_packer_instruction_plan_from_instructions(instructions(7))
      plan        = planner.call(packer_plan)

      expect(plan.kind).to eq(:sequential)
      expect(plan.plans.map { |p| p.message.instructions.length }).to eq([3, 3, 1])
    end

    it 'raises for a zero max_instructions_per_transaction' do
      planner = described_class.create_transaction_planner(
        create_transaction_message: create_transaction_message,
        max_instructions_per_transaction: 0
      )

      expect { planner.call(described_class.sequential_instruction_plan(instructions(1))) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::INSTRUCTION_PLANS__INVALID_MAX_INSTRUCTIONS_PER_TRANSACTION)
        }
    end

    it 'raises for a max_instructions_per_transaction above the 64-instruction transaction format limit' do
      planner = described_class.create_transaction_planner(
        create_transaction_message: create_transaction_message,
        max_instructions_per_transaction: 65
      )

      expect { planner.call(described_class.sequential_instruction_plan(instructions(1))) }
        .to raise_error(RubyKit::SolanaError) { |e|
          expect(e.code).to eq(RubyKit::SolanaError::INSTRUCTION_PLANS__INVALID_MAX_INSTRUCTIONS_PER_TRANSACTION)
        }
    end
  end
end
