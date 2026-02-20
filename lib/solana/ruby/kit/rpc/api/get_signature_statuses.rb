# typed: strict
# frozen_string_literal: true

require_relative '../../rpc_types/account_info'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Status of a confirmed transaction signature.
      # Mirrors TypeScript's signature-status response shape.
      class SignatureStatus < T::Struct
        const :slot,                 Integer
        const :confirmations,        T.nilable(Integer)   # nil when finalized
        const :err,                  T.untyped            # nil or error object
        const :confirmation_status,  T.nilable(Symbol)    # :processed | :confirmed | :finalized
      end

      # Returns the confirmation status of one or more transaction signatures.
      # Mirrors TypeScript's `GetSignatureStatusesApi.getSignatureStatuses(sigs, config?)`.
      #
      # Returns a `RpcContextualValue` with:
      #   .slot  — context slot
      #   .value — Array of SignatureStatus | nil (nil for unknown signatures)
      module GetSignatureStatuses
        extend T::Sig

        sig do
          params(
            signatures:            T::Array[String],
            search_transaction_history: T::Boolean
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_signature_statuses(signatures, search_transaction_history: false)
          config = { 'searchTransactionHistory' => search_transaction_history }
          result = transport.request('getSignatureStatuses', [signatures, config])

          statuses = result['value'].map do |raw|
            next nil if raw.nil?

            SignatureStatus.new(
              slot:                Kernel.Integer(raw['slot']),
              confirmations:       raw['confirmations'] ? Kernel.Integer(raw['confirmations']) : nil,
              err:                 raw['err'],
              confirmation_status: raw['confirmationStatus']&.to_sym
            )
          end

          RpcTypes::RpcContextualValue.new(
            slot:  Kernel.Integer(result['context']['slot']),
            value: statuses
          )
        end
      end
    end
  end
end
