# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch a confirmed transaction.
      # Mirrors TypeScript's GetTransactionApi.getTransaction.
      # Returns the raw JSON hash (nil if not found / not yet confirmed).
      module GetTransaction
        extend T::Sig

        sig do
          params(
            signature:                          String,
            encoding:                           String,
            commitment:                         T.nilable(Symbol),
            max_supported_transaction_version:  T.nilable(Integer)
          ).returns(T.nilable(T::Hash[String, T.untyped]))
        end
        def get_transaction(
          signature,
          encoding:                          'json',
          commitment:                        nil,
          max_supported_transaction_version: nil
        )
          config = { 'encoding' => encoding }
          config['commitment'] = commitment.to_s if commitment
          config['maxSupportedTransactionVersion'] = max_supported_transaction_version if max_supported_transaction_version

          transport.request('getTransaction', [signature, config])
        end
      end
    end
  end
end
