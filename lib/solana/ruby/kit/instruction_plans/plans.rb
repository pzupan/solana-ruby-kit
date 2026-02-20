# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module InstructionPlans
    # A plan that wraps a single instruction.
    class SingleInstructionPlan < T::Struct
      const :instruction, Instructions::Instruction
    end

    # A plan that executes a sequence of sub-plans in order.
    # When +divisible+ is true the planner may split steps across transactions.
    class SequentialInstructionPlan < T::Struct
      const :steps,     T::Array[T.untyped]  # Array[InstructionPlan]
      const :divisible, T::Boolean, default: false
    end

    # A plan whose sub-plans may execute concurrently or be packed into the
    # same transaction in any order.
    class ParallelInstructionPlan < T::Struct
      const :plans, T::Array[T.untyped]  # Array[InstructionPlan]
    end

    # Union type alias (used only in doc strings; Ruby is duck-typed).
    # InstructionPlan = SingleInstructionPlan | SequentialInstructionPlan | ParallelInstructionPlan
  end
end
