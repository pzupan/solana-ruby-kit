# typed: strict
# frozen_string_literal: true

require 'base64'
require_relative '../../keys/signatures'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Submits a signed transaction to the cluster for processing.
      # Mirrors TypeScript's `SendTransactionApi.sendTransaction(transaction, config?)`.
      #
      # Accepts the transaction in two forms:
      #   - A `Solana::Ruby::Kit::Transactions::Transaction` struct (wire bytes are base64-encoded internally).
      #   - A raw base64 String (the already-encoded wire transaction).
      #
      # Returns a `Solana::Ruby::Kit::Keys::Signature` (base58-encoded transaction signature).
      #
      # Note: This method returns as soon as the node receives the transaction; it does
      # NOT wait for confirmation.  Use `get_signature_statuses` to poll for commitment.
      module SendTransaction
        extend T::Sig

        sig do
          params(
            transaction:          T.untyped,  # Transactions::Transaction or String (base64)
            skip_preflight:       T::Boolean,
            preflight_commitment: T.nilable(Symbol),
            max_retries:          T.nilable(Integer),
            min_context_slot:     T.nilable(Integer)
          ).returns(Keys::Signature)
        end
        def send_transaction(
          transaction,
          skip_preflight:       false,
          preflight_commitment: nil,
          max_retries:          nil,
          min_context_slot:     nil
        )
          wire_base64 =
            case transaction
            when String
              transaction
            else
              # Assume it responds to .message_bytes (Transactions::Transaction)
              Base64.strict_encode64(transaction.message_bytes)
            end

          config = { 'encoding' => 'base64' }
          config['skipPreflight']       = skip_preflight if skip_preflight
          config['preflightCommitment'] = preflight_commitment.to_s if preflight_commitment
          config['maxRetries']          = max_retries if max_retries
          config['minContextSlot']      = min_context_slot if min_context_slot

          sig_str = transport.request('sendTransaction', [wire_base64, config])
          Keys::Signature.new(sig_str)
        end
      end
    end
  end
end
