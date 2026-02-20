# typed: strict
# frozen_string_literal: true

# Mirrors @solana/instruction-plans.
# An InstructionPlan describes operations that may span multiple transactions.
require_relative 'instruction_plans/plans'

module Solana::Ruby::Kit
  module InstructionPlans
    extend T::Sig

    module_function

    # Build a plan that wraps a single instruction.
    sig { params(instruction: Instructions::Instruction).returns(SingleInstructionPlan) }
    def single_instruction_plan(instruction)
      SingleInstructionPlan.new(instruction: instruction)
    end

    # Build a sequential plan from an array of sub-plans.
    sig { params(steps: T::Array[T.untyped], divisible: T::Boolean).returns(SequentialInstructionPlan) }
    def sequential_instruction_plan(steps, divisible: false)
      SequentialInstructionPlan.new(steps: steps, divisible: divisible)
    end

    # Build a parallel plan from an array of sub-plans.
    sig { params(plans: T::Array[T.untyped]).returns(ParallelInstructionPlan) }
    def parallel_instruction_plan(plans)
      ParallelInstructionPlan.new(plans: plans)
    end

    # Flatten a plan tree into a single ordered Array of Instructions.
    sig { params(plan: T.untyped).returns(T::Array[Instructions::Instruction]) }
    def flatten_instruction_plan(plan)
      case plan
      when SingleInstructionPlan
        [plan.instruction]
      when SequentialInstructionPlan
        plan.steps.flat_map { |s| flatten_instruction_plan(s) }
      when ParallelInstructionPlan
        plan.plans.flat_map { |p| flatten_instruction_plan(p) }
      else
        Kernel.raise ArgumentError, "Unknown InstructionPlan type: #{plan.class}"
      end
    end
  end
end
