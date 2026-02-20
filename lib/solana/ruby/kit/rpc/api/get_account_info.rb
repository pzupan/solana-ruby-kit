# typed: strict
# frozen_string_literal: true

require 'base64'
require_relative '../../rpc_types/account_info'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetches all stored information for an account at the given address.
      # Mirrors TypeScript's `GetAccountInfoApi.getAccountInfo(address, config?)`.
      #
      # Returns a `RpcContextualValue` with:
      #   .slot  — context slot
      #   .value — AccountInfoWithBase64Data | AccountInfoWithJsonData | nil
      #            (nil when the account does not exist)
      module GetAccountInfo
        extend T::Sig

        SUPPORTED_ENCODINGS = T.let(%w[base64 jsonParsed base64+zstd].freeze, T::Array[String])

        sig do
          params(
            address:          String,
            encoding:         String,
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer),
            data_slice:       T.nilable(T::Hash[String, Integer])
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_account_info(
          address,
          encoding:         'base64',
          commitment:       nil,
          min_context_slot: nil,
          data_slice:       nil
        )
          config = { 'encoding' => encoding }
          config['commitment']      = commitment.to_s if commitment
          config['minContextSlot']  = min_context_slot if min_context_slot
          config['dataSlice']       = data_slice if data_slice

          result = transport.request('getAccountInfo', [address, config])

          slot = Kernel.Integer(result['context']['slot'])
          raw  = result['value']

          value =
            if raw.nil?
              nil
            elsif encoding == 'jsonParsed'
              RpcTypes::AccountInfoWithJsonData.new(
                executable: raw['executable'],
                lamports:   Kernel.Integer(raw['lamports']),
                owner:      raw['owner'],
                space:      Kernel.Integer(raw.fetch('space', 0)),
                rent_epoch: Kernel.Integer(raw.fetch('rentEpoch', 0)),
                data:       raw['data']
              )
            else
              RpcTypes::AccountInfoWithBase64Data.new(
                executable: raw['executable'],
                lamports:   Kernel.Integer(raw['lamports']),
                owner:      raw['owner'],
                space:      Kernel.Integer(raw.fetch('space', 0)),
                rent_epoch: Kernel.Integer(raw.fetch('rentEpoch', 0)),
                data:       Kernel.Array(raw['data'])
              )
            end

          RpcTypes::RpcContextualValue.new(slot: slot, value: value)
        end
      end
    end
  end
end
