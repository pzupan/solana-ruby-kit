# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Struct returned by get_epoch_schedule.
      EpochSchedule = T.let(
        Struct.new(
          :first_normal_epoch,        # Integer — first full-length epoch after warmup
          :first_normal_slot,         # Integer — first slot after warmup period
          :leader_schedule_slot_offset, # Integer — slots before epoch to compute leader schedule
          :slots_per_epoch,           # Integer — max slots per epoch
          :warmup,                    # Boolean — whether epochs start short and grow
          keyword_init: true
        ),
        T.untyped
      )

      # Returns the epoch schedule from the cluster's genesis config.
      # Mirrors TypeScript's GetEpochScheduleApi.getEpochSchedule.
      module GetEpochSchedule
        extend T::Sig

        sig { returns(T.untyped) }
        def get_epoch_schedule
          raw = transport.request('getEpochSchedule', [])

          EpochSchedule.new(
            first_normal_epoch:           Kernel.Integer(raw['firstNormalEpoch']),
            first_normal_slot:            Kernel.Integer(raw['firstNormalSlot']),
            leader_schedule_slot_offset:  Kernel.Integer(raw['leaderScheduleSlotOffset']),
            slots_per_epoch:              Kernel.Integer(raw['slotsPerEpoch']),
            warmup:                       raw['warmup'] == true
          )
        end
      end
    end
  end
end
