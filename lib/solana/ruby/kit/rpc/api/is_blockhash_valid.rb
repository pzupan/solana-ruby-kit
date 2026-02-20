# typed: strict
# frozen_string_literal: true

require_relative '../../rpc_types/account_info'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns whether a blockhash is still valid (not yet expired).
      # Mirrors TypeScript's `IsBlockhashValidApi.isBlockhashValid(blockhash, config?)`.
      #
      # Returns a `RpcContextualValue` with:
      #   .slot  — context slot
      #   .value — Boolean
      module IsBlockhashValid
        extend T::Sig

        sig do
          params(
            blockhash:        String,
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def is_blockhash_valid(blockhash, commitment: nil, min_context_slot: nil)
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [blockhash] : [blockhash, config]
          result = transport.request('isBlockhashValid', params)

          RpcTypes::RpcContextualValue.new(
            slot:  Kernel.Integer(result['context']['slot']),
            value: result['value'] == true
          )
        end
      end
    end
  end
end
