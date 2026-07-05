# typed: strict
# frozen_string_literal: true

require_relative '../instructions/instruction'

module Solana::Ruby::Kit
  module TransactionIntrospection
    # A ResolvedInstruction carrying its location in the transaction as a
    # `trace` Hash.
    #
    # TypeScript flattens `TracedInstruction` into the instruction itself
    # (`ResolvedInstruction & { trace }`), so callers there access
    # `ix.programAddress` directly. Ruby's `Instructions::Instruction` is a
    # `T::Struct`, which is final and cannot be subclassed (see
    # `Transactions::FullySignedTransaction` for the same constraint), so here
    # the instruction and its trace are held as sibling fields instead:
    # `traced.instruction.program_address`, `traced.trace`.
    #
    # `trace` is one of:
    #   { kind: :outer, index: Integer }
    #   { kind: :inner, outer_index: Integer, inner_index: Integer, stack_height: T.nilable(Integer) }
    #
    # Mirrors `TracedInstruction` / `InstructionTrace` from @solana/transaction-introspection.
    class TracedInstruction < T::Struct
      const :instruction, Instructions::Instruction
      const :trace,       T::Hash[Symbol, T.untyped]
    end
  end
end
