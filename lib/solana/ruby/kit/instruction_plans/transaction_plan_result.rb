# typed: strict
# frozen_string_literal: true

require_relative '../errors'
require_relative '../transaction_messages/transaction_message'
require_relative '../transactions/transaction'

module Solana::Ruby::Kit
  module InstructionPlans
    extend T::Sig

    # ── Result status types ───────────────────────────────────────────────────
    #
    # Each single transaction produces one of three statuses:
    #   successful: { kind: :successful, transaction:, context: }
    #   failed:     { kind: :failed,     error: }
    #   canceled:   { kind: :canceled }
    #
    # Mirrors TypeScript's TransactionPlanResultStatus union.

    class SuccessfulStatus < T::Struct
      const :transaction, Transactions::Transaction
      const :context,     T::Hash[T.untyped, T.untyped]
      def kind = :successful
    end

    class FailedStatus < T::Struct
      const :error, SolanaError
      def kind = :failed
    end

    class CanceledStatus < T::Struct
      def kind = :canceled
    end

    # ── Result plan types ──────────────────────────────────────────────────────

    class SingleTransactionPlanResult < T::Struct
      const :message, TransactionMessages::TransactionMessage
      const :status,  T.untyped  # SuccessfulStatus | FailedStatus | CanceledStatus
      def kind = :single
    end

    class SequentialTransactionPlanResult < T::Struct
      const :plans,     T::Array[T.untyped]  # Array[TransactionPlanResult]
      const :divisible, T::Boolean
      def kind = :sequential
    end

    class ParallelTransactionPlanResult < T::Struct
      const :plans, T::Array[T.untyped]  # Array[TransactionPlanResult]
      def kind = :parallel
    end

    module_function

    # ── Result factory helpers ────────────────────────────────────────────────

    # Mirrors `sequentialTransactionPlanResult(plans)`.
    sig { params(plans: T::Array[T.untyped]).returns(SequentialTransactionPlanResult) }
    def sequential_transaction_plan_result(plans)
      SequentialTransactionPlanResult.new(plans: plans, divisible: true)
    end

    # Mirrors `nonDivisibleSequentialTransactionPlanResult(plans)`.
    sig { params(plans: T::Array[T.untyped]).returns(SequentialTransactionPlanResult) }
    def non_divisible_sequential_transaction_plan_result(plans)
      SequentialTransactionPlanResult.new(plans: plans, divisible: false)
    end

    # Mirrors `parallelTransactionPlanResult(plans)`.
    sig { params(plans: T::Array[T.untyped]).returns(ParallelTransactionPlanResult) }
    def parallel_transaction_plan_result(plans)
      ParallelTransactionPlanResult.new(plans: plans)
    end

    # Mirrors `successfulSingleTransactionPlanResult(message, transaction, context)`.
    sig do
      params(
        message:     TransactionMessages::TransactionMessage,
        transaction: Transactions::Transaction,
        context:     T::Hash[T.untyped, T.untyped]
      ).returns(SingleTransactionPlanResult)
    end
    def successful_single_transaction_plan_result(message, transaction, context = {})
      SingleTransactionPlanResult.new(
        message: message,
        status:  SuccessfulStatus.new(transaction: transaction, context: context)
      )
    end

    # Mirrors `failedSingleTransactionPlanResult(message, error)`.
    sig do
      params(
        message: TransactionMessages::TransactionMessage,
        error:   SolanaError
      ).returns(SingleTransactionPlanResult)
    end
    def failed_single_transaction_plan_result(message, error)
      SingleTransactionPlanResult.new(
        message: message,
        status:  FailedStatus.new(error: error)
      )
    end

    # Mirrors `canceledSingleTransactionPlanResult(message)`.
    sig do
      params(message: TransactionMessages::TransactionMessage).returns(SingleTransactionPlanResult)
    end
    def canceled_single_transaction_plan_result(message)
      SingleTransactionPlanResult.new(
        message: message,
        status:  CanceledStatus.new
      )
    end
  end
end
