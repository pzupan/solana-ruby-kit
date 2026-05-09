# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Struct for a single entry in the getInflationReward response.
      # nil entries indicate the address was not found or had no reward.
      InflationReward = T.let(
        Struct.new(
          :amount,         # Integer (Lamports) — reward credited
          :commission,     # Integer — vote account commission at reward time
          :effective_slot, # Integer — slot in which rewards were delivered
          :epoch,          # Integer — epoch for which reward occurred
          :post_balance,   # Integer (Lamports) — post-reward account balance
          keyword_init: true
        ),
        T.untyped
      )

      # Returns the inflation/staking reward for a list of addresses for an epoch.
      # Mirrors TypeScript's GetInflationRewardApi.getInflationReward.
      module GetInflationReward
        extend T::Sig

        sig do
          params(
            addresses:        T::Array[T.untyped],
            commitment:       T.nilable(Symbol),
            epoch:            T.nilable(Integer),
            min_context_slot: T.nilable(Integer)
          ).returns(T::Array[T.nilable(T.untyped)])
        end
        def get_inflation_reward(addresses, commitment: nil, epoch: nil, min_context_slot: nil)
          addr_strings = addresses.map { |a| a.respond_to?(:value) ? a.value : a.to_s }
          config = {}
          config['commitment']      = commitment.to_s if commitment
          config['epoch']           = epoch           if epoch
          config['minContextSlot']  = min_context_slot if min_context_slot

          params = config.empty? ? [addr_strings] : [addr_strings, config]
          raw_list = transport.request('getInflationReward', params)

          raw_list.map do |entry|
            next nil if entry.nil?

            InflationReward.new(
              amount:         Kernel.Integer(entry['amount']),
              commission:     Kernel.Integer(entry['commission']),
              effective_slot: Kernel.Integer(entry['effectiveSlot']),
              epoch:          Kernel.Integer(entry['epoch']),
              post_balance:   Kernel.Integer(entry['postBalance'])
            )
          end
        end
      end
    end
  end
end
