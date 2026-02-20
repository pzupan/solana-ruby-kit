# typed: strict
# frozen_string_literal: true

require_relative '../../keys/signatures'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Requests an airdrop of lamports to the given address.
      # Only available on devnet and testnet.
      # Mirrors TypeScript's `RequestAirdropApi.requestAirdrop(address, lamports, config?)`.
      #
      # Returns the transaction `Signature` of the airdrop.
      module RequestAirdrop
        extend T::Sig

        sig do
          params(
            address:    String,
            lamports:   Integer,
            commitment: T.nilable(Symbol)
          ).returns(Keys::Signature)
        end
        def request_airdrop(address, lamports, commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          params = config.empty? ? [address, lamports] : [address, lamports, config]
          sig_str = transport.request('requestAirdrop', params)
          Keys::Signature.new(sig_str)
        end
      end
    end
  end
end
