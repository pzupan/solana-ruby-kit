# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Struct returned by get_epoch_info.
      EpochInfo = T.let(
        Struct.new(
          :absolute_slot,       # Integer — current slot
          :block_height,        # Integer
          :epoch,               # Integer — current epoch
          :slot_index,          # Integer — slot within current epoch
          :slots_in_epoch,      # Integer — total slots in epoch
          :transaction_count,   # Integer | nil
          keyword_init: true
        ),
        T.untyped
      )

      # Fetch information about the current epoch.
      # Mirrors TypeScript's GetEpochInfoApi.getEpochInfo.
      module GetEpochInfo
        extend T::Sig

        sig do
          params(commitment: T.nilable(Symbol)).returns(T.untyped)
        end
        def get_epoch_info(commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          raw = transport.request('getEpochInfo', config.empty? ? [] : [config])

          EpochInfo.new(
            absolute_slot:     Kernel.Integer(raw['absoluteSlot']),
            block_height:      Kernel.Integer(raw['blockHeight']),
            epoch:             Kernel.Integer(raw['epoch']),
            slot_index:        Kernel.Integer(raw['slotIndex']),
            slots_in_epoch:    Kernel.Integer(raw['slotsInEpoch']),
            transaction_count: raw['transactionCount'] ? Kernel.Integer(raw['transactionCount']) : nil
          )
        end
      end
    end
  end
end
