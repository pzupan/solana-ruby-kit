# typed: strict
# frozen_string_literal: true

require_relative '../../rpc_types/account_info'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # The payload returned by getLatestBlockhash.
      # Mirrors TypeScript's `GetLatestBlockhashApiResponse`.
      class LatestBlockhash < T::Struct
        const :blockhash,               String   # base58-encoded 32 bytes
        const :last_valid_block_height, Integer  # TypeScript bigint → Ruby Integer
      end

      # Returns the latest blockhash and its expiry block height.
      # Mirrors TypeScript's `GetLatestBlockhashApi.getLatestBlockhash(config?)`.
      #
      # Returns a `RpcContextualValue` with:
      #   .slot  — context slot
      #   .value — LatestBlockhash
      module GetLatestBlockhash
        extend T::Sig

        sig do
          params(
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_latest_blockhash(commitment: nil, min_context_slot: nil)
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [] : [config]
          result = transport.request('getLatestBlockhash', params)

          value = LatestBlockhash.new(
            blockhash:               result['value']['blockhash'],
            last_valid_block_height: Kernel.Integer(result['value']['lastValidBlockHeight'])
          )

          RpcTypes::RpcContextualValue.new(
            slot:  Kernel.Integer(result['context']['slot']),
            value: value
          )
        end
      end
    end
  end
end
