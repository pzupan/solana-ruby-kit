# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the estimated production time of a block.
      # Mirrors TypeScript's GetBlockTimeApi.getBlockTime.
      module GetBlockTime
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig { params(slot: Integer).returns(T.nilable(Integer)) }
        def get_block_time(slot)
          raw = transport.request('getBlockTime', [slot])
          raw.nil? ? nil : Kernel.Integer(raw)
        end
      end
    end
  end
end
