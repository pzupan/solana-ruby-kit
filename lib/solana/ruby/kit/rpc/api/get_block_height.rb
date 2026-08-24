# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the current block height of the node.
      # Mirrors TypeScript's `GetBlockHeightApi.getBlockHeight(config?)`.
      module GetBlockHeight
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

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
