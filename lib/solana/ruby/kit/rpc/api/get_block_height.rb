# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the current block height of the node.
      # Mirrors TypeScript's `GetBlockHeightApi.getBlockHeight(config?)`.
      module GetBlockHeight
        extend T::Sig

        sig do
          params(
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(Integer)
        end
        def get_block_height(commitment: nil, min_context_slot: nil)
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [] : [config]
          Kernel.Integer(transport.request('getBlockHeight', params))
        end
      end
    end
  end
end
