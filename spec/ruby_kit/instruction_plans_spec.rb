# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::InstructionPlans do
  let(:dummy_instruction) do
    RubyKit::Instructions::Instruction.new(
      program_address: RubyKit::Addresses.address('11111111111111111111111111111111'),
      accounts:        [],
      data:            ''
    )
  end

  describe '.single_instruction_plan' do
    it 'wraps one instruction' do
      plan = described_class.single_instruction_plan(dummy_instruction)
      expect(plan).to be_a(RubyKit::InstructionPlans::SingleInstructionPlan)
      expect(plan.instruction).to eq(dummy_instruction)
    end
  end

  describe '.sequential_instruction_plan' do
    it 'holds steps and divisible flag' do
      step  = described_class.single_instruction_plan(dummy_instruction)
      plan  = described_class.sequential_instruction_plan([step], divisible: true)
      expect(plan.steps.length).to eq(1)
      expect(plan.divisible).to   be true
    end
  end

  describe '.parallel_instruction_plan' do
    it 'holds sub-plans' do
      step = described_class.single_instruction_plan(dummy_instruction)
      plan = described_class.parallel_instruction_plan([step, step])
      expect(plan.plans.length).to eq(2)
    end
  end

  describe '.flatten_instruction_plan' do
    it 'extracts all instructions from a nested plan' do
      a = described_class.single_instruction_plan(dummy_instruction)
      b = described_class.single_instruction_plan(dummy_instruction)
      seq  = described_class.sequential_instruction_plan([a, b])
      par  = described_class.parallel_instruction_plan([seq])
      root = described_class.sequential_instruction_plan([par])

      flat = described_class.flatten_instruction_plan(root)
      expect(flat.length).to eq(2)
      expect(flat).to all(be_a(RubyKit::Instructions::Instruction))
    end
  end
end
