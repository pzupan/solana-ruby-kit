# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the current slot number at the given commitment level.
      # Mirrors TypeScript's `GetSlotApi.getSlot()`.
      module GetSlot
        extend T::Sig

        sig do
          params(
            commitment:      T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(Integer)
        end
        def get_slot(commitment: nil, min_context_slot: nil)
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [] : [config]
          result = transport.request('getSlot', params)
          Kernel.Integer(result)
        end
      end
    end
  end
end
