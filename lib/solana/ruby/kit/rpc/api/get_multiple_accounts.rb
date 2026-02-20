# typed: strict
# frozen_string_literal: true

require 'base64'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch multiple account infos in a single RPC call.
      # Mirrors TypeScript's GetMultipleAccountsApi.getMultipleAccounts.
      module GetMultipleAccounts
        extend T::Sig

        sig do
          params(
            addresses:        T::Array[String],
            encoding:         String,
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer),
            data_slice:       T.nilable(T::Hash[String, Integer])
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_multiple_accounts(
          addresses,
          encoding:         'base64',
          commitment:       nil,
          min_context_slot: nil,
          data_slice:       nil
        )
          config = { 'encoding' => encoding }
          config['commitment']     = commitment.to_s if commitment
          config['minContextSlot'] = min_context_slot if min_context_slot
          config['dataSlice']      = data_slice if data_slice

          result = transport.request('getMultipleAccounts', [addresses, config])

          slot   = Kernel.Integer(result['context']['slot'])
          values = Kernel.Array(result['value']).map do |raw|
            next nil if raw.nil?

            RpcTypes::AccountInfoWithBase64Data.new(
              executable: raw['executable'],
              lamports:   Kernel.Integer(raw['lamports']),
              owner:      raw['owner'],
              space:      Kernel.Integer(raw.fetch('space', 0)),
              rent_epoch: Kernel.Integer(raw.fetch('rentEpoch', 0)),
              data:       Kernel.Array(raw['data'])
            )
          end

          RpcTypes::RpcContextualValue.new(slot: slot, value: values)
        end
      end
    end
  end
end
