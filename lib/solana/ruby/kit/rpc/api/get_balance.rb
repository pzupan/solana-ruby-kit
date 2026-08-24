# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'
require_relative '../../rpc_types/account_info'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the lamport balance of an account.
      # Mirrors TypeScript's `GetBalanceApi.getBalance(address, config?)`.
      #
      # Returns a `RpcContextualValue` with:
      #   .slot  — the slot at which the balance was read
      #   .value — Integer (lamports)
      module GetBalance
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig do
          params(
            address:          String,
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_balance(address, commitment: nil, min_context_slot: nil)
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [address] : [address, config]
          result = transport.request('getBalance', params)

          RpcTypes::RpcContextualValue.new(
            slot:  Kernel.Integer(result['context']['slot']),
            value: Kernel.Integer(result['value'])
          )
        end
      end
    end
  end
end
