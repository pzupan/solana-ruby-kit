# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch all SPL Token accounts by owner.
      # +filter+ must be one of:
      #   { 'mint' => mint_address }
      #   { 'programId' => program_id }
      module GetTokenAccountsByOwner
        extend T::Sig

        sig do
          params(
            owner:      String,
            filter:     T::Hash[String, String],
            encoding:   String,
            commitment: T.nilable(Symbol)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_token_accounts_by_owner(owner, filter, encoding: 'base64', commitment: nil)
          config = { 'encoding' => encoding }
          config['commitment'] = commitment.to_s if commitment

          result = transport.request('getTokenAccountsByOwner', [owner, filter, config])
          slot   = Kernel.Integer(result['context']['slot'])
          value  = Kernel.Array(result['value']).map do |item|
            raw = item['account']
            {
              pubkey:  item['pubkey'],
              account: RpcTypes::AccountInfoWithBase64Data.new(
                executable: raw['executable'],
                lamports:   Kernel.Integer(raw['lamports']),
                owner:      raw['owner'],
                space:      Kernel.Integer(raw.fetch('space', 0)),
                rent_epoch: Kernel.Integer(raw.fetch('rentEpoch', 0)),
                data:       Kernel.Array(raw['data'])
              )
            }
          end

          RpcTypes::RpcContextualValue.new(slot: slot, value: value)
        end
      end
    end
  end
end
