# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch the total supply of an SPL Token mint.
      # Mirrors TypeScript's GetTokenSupplyApi.getTokenSupply.
      module GetTokenSupply
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig do
          params(
            token_mint: String,
            commitment: T.nilable(Symbol)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_token_supply(token_mint, commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          result = transport.request('getTokenSupply', [token_mint, config].tap { |a| a.pop if a.last.empty? })
          slot   = Kernel.Integer(result['context']['slot'])
          raw    = result['value']

          value = {
            amount:           raw['amount'],
            decimals:         Kernel.Integer(raw['decimals']),
            ui_amount:        raw['uiAmount'],
            ui_amount_string: raw['uiAmountString']
          }

          RpcTypes::RpcContextualValue.new(slot: slot, value: value)
        end
      end
    end
  end
end
