# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Simulate a transaction without broadcasting it.
      # Mirrors TypeScript's SimulateTransactionApi.simulateTransaction.
      # Returns an RpcContextualValue whose value is the simulation result hash.
      module SimulateTransaction
        extend T::Sig

        sig do
          params(
            encoded_transaction: String,
            encoding:            String,
            commitment:          T.nilable(Symbol),
            sig_verify:          T::Boolean,
            replace_recent_blockhash: T::Boolean,
            accounts:            T.nilable(T::Hash[String, T.untyped])
          ).returns(RpcTypes::RpcContextualValue)
        end
        def simulate_transaction(
          encoded_transaction,
          encoding:                 'base64',
          commitment:               nil,
          sig_verify:               false,
          replace_recent_blockhash: false,
          accounts:                 nil
        )
          config = {
            'encoding'              => encoding,
            'sigVerify'             => sig_verify,
            'replaceRecentBlockhash' => replace_recent_blockhash
          }
          config['commitment'] = commitment.to_s if commitment
          config['accounts']   = accounts if accounts

          result = transport.request('simulateTransaction', [encoded_transaction, config])
          slot   = Kernel.Integer(result['context']['slot'])

          RpcTypes::RpcContextualValue.new(slot: slot, value: result['value'])
        end
      end
    end
  end
end
