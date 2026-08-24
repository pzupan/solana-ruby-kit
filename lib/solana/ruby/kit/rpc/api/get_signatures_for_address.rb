# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Struct representing one transaction signature entry returned by getSignaturesForAddress.
      # Mirrors TypeScript's GetSignaturesForAddressTransaction.
      SignatureInfo = T.let(
        Struct.new(
          :block_time,         # Integer | nil — Unix timestamp of block production, nil if unavailable
          :confirmation_status, # Symbol | nil — :processed, :confirmed, or :finalized
          :err,                # Hash | nil — transaction error, nil if succeeded
          :memo,               # String | nil — memo associated with the transaction
          :signature,          # String — base-58 encoded transaction signature
          :slot,               # Integer — slot containing the transaction
          :transaction_index,  # Integer | nil — 0-based index within block (Agave 4.0+)
          keyword_init: true
        ),
        T.untyped
      )

      # Returns confirmed transaction signatures that reference the given address.
      # Mirrors TypeScript's GetSignaturesForAddressApi.getSignaturesForAddress.
      # See https://solana.com/docs/rpc/http/getsignaturesforaddress
      module GetSignaturesForAddress
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig do
          params(
            address:          String,
            before:           T.nilable(String),
            until_sig:        T.nilable(String),
            limit:            T.nilable(Integer),
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer)
          ).returns(T::Array[T.untyped])
        end
        def get_signatures_for_address(
          address,
          before:           nil,
          until_sig:        nil,
          limit:            nil,
          commitment:       nil,
          min_context_slot: nil
        )
          config = {}
          config['before']           = before if before
          config['until']            = until_sig if until_sig
          config['limit']            = limit if limit
          config['commitment']       = commitment.to_s if commitment
          config['minContextSlot']   = min_context_slot if min_context_slot

          params = config.empty? ? [address] : [address, config]
          result = transport.request('getSignaturesForAddress', params)

          result.map do |tx|
            SignatureInfo.new(
              block_time:          tx['blockTime'],
              confirmation_status: tx['confirmationStatus']&.to_sym,
              err:                 tx['err'],
              memo:                tx['memo'],
              signature:           tx['signature'],
              slot:                Kernel.Integer(tx['slot']),
              transaction_index:   tx['transactionIndex']
            )
          end
        end
      end
    end
  end
end
