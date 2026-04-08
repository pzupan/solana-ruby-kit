# typed: strict
# frozen_string_literal: true

require_relative '../errors'
require_relative 'transaction_plan'
require_relative 'transaction_plan_result'

module Solana::Ruby::Kit
  module InstructionPlans
    extend T::Sig

    # Creates a TransactionPlanExecutor — a callable that traverses a TransactionPlan,
    # executing each single transaction message and collecting results.
    #
    # Configuration:
    #   execute_transaction_message: ->(message) { { transaction:, context: } }
    #     Called for each SingleTransactionPlan. Must return a hash with:
    #       :transaction — the signed Transaction
    #       :context     — optional Hash of extra data (defaults to {})
    #     Raise a SolanaError to signal failure; remaining plans will be canceled.
    #
    # The returned executor is a lambda: executor.call(transaction_plan) -> TransactionPlanResult
    #
    # Mirrors `createTransactionPlanExecutor(config)` from @solana/instruction-plans.
    # NOTE: Ruby translation is synchronous; abort-signal support is omitted.
    sig { params(execute_transaction_message: T.untyped).returns(T.untyped) }
    def create_transaction_plan_executor(execute_transaction_message:)
      ->(transaction_plan) {
        state  = { canceled: false }
        result = executor_traverse(transaction_plan, execute_transaction_message, state)

        if state[:canceled]
          cause = executor_find_error(result)
          err   = SolanaError.new(
            SolanaError::INSTRUCTION_PLANS__FAILED_TO_EXECUTE_TRANSACTION_PLAN,
            { cause: cause }
          )
          # Store the full result tree as a non-enumerable attribute for recovery.
          err.instance_variable_set(:@transaction_plan_result, result)
          err.define_singleton_method(:transaction_plan_result) { @transaction_plan_result }
          Kernel.raise err
        end

        result
      }
    end

    module_function :create_transaction_plan_executor

    # ── Private helpers ────────────────────────────────────────────────────────

    module_function

    def executor_traverse(plan, execute_fn, state)
      case plan.kind
      when :sequential then executor_traverse_sequential(plan, execute_fn, state)
      when :parallel   then executor_traverse_parallel(plan, execute_fn, state)
      when :single     then executor_traverse_single(plan, execute_fn, state)
      else
        Kernel.raise SolanaError.new(
          SolanaError::INVARIANT_VIOLATION__INVALID_TRANSACTION_PLAN_KIND,
          { kind: plan.kind }
        )
      end
    end

    def executor_traverse_sequential(plan, execute_fn, state)
      results = plan.plans.map { |sub| executor_traverse(sub, execute_fn, state) }
      plan.divisible \
        ? sequential_transaction_plan_result(results) \
        : non_divisible_sequential_transaction_plan_result(results)
    end

    def executor_traverse_parallel(plan, execute_fn, state)
      results = plan.plans.map { |sub| executor_traverse(sub, execute_fn, state) }
      parallel_transaction_plan_result(results)
    end

    def executor_traverse_single(plan, execute_fn, state)
      return canceled_single_transaction_plan_result(plan.message) if state[:canceled]

      begin
        result      = execute_fn.call(plan.message)
        transaction = result.fetch(:transaction)
        context     = result.fetch(:context, {})
        successful_single_transaction_plan_result(plan.message, transaction, context)
      rescue SolanaError => e
        state[:canceled] = true
        failed_single_transaction_plan_result(plan.message, e)
      rescue => e
        state[:canceled] = true
        wrapped = SolanaError.new(
          SolanaError::INSTRUCTION_PLANS__FAILED_TO_EXECUTE_TRANSACTION_PLAN,
          { cause: e }
        )
        failed_single_transaction_plan_result(plan.message, wrapped)
      end
    end

    def executor_find_error(result)
      return result.status.error if result.kind == :single && result.status.kind == :failed
      return nil                 if result.kind == :single

      result.plans.each do |sub|
        err = executor_find_error(sub)
        return err if err
      end
      nil
    end

    private_class_method :executor_traverse
    private_class_method :executor_traverse_sequential
    private_class_method :executor_traverse_parallel
    private_class_method :executor_traverse_single
    private_class_method :executor_find_error
  end
end
