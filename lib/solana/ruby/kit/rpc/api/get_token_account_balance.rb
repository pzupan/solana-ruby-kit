# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch the token balance of an SPL Token account.
      # Mirrors TypeScript's GetTokenAccountBalanceApi.getTokenAccountBalance.
      module GetTokenAccountBalance
        extend T::Sig

        sig do
          params(
            token_account: String,
            commitment:    T.nilable(Symbol)
          ).returns(RpcTypes::RpcContextualValue)
        end
        def get_token_account_balance(token_account, commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          result = transport.request('getTokenAccountBalance', [token_account, config].tap { |a| a.pop if a.last.empty? })
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
