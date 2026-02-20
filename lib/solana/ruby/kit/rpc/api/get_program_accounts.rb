# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Fetch all accounts owned by a program.
      # Mirrors TypeScript's GetProgramAccountsApi.getProgramAccounts.
      #
      # Returns an Array of { pubkey:, account: AccountInfoWithBase64Data }.
      module GetProgramAccounts
        extend T::Sig

        sig do
          params(
            program_id:       String,
            encoding:         String,
            filters:          T::Array[T::Hash[String, T.untyped]],
            commitment:       T.nilable(Symbol),
            min_context_slot: T.nilable(Integer),
            with_context:     T::Boolean
          ).returns(T.untyped)
        end
        def get_program_accounts(
          program_id,
          encoding:         'base64',
          filters:          [],
          commitment:       nil,
          min_context_slot: nil,
          with_context:     false
        )
          config = { 'encoding' => encoding, 'withContext' => with_context }
          config['filters']        = filters        unless filters.empty?
          config['commitment']     = commitment.to_s if commitment
          config['minContextSlot'] = min_context_slot if min_context_slot

          result = transport.request('getProgramAccounts', [program_id, config])

          # withContext wraps result in {context:, value:}
          accounts = with_context ? result['value'] : result

          Kernel.Array(accounts).map do |item|
            account_raw = item['account']
            {
              pubkey:  item['pubkey'],
              account: RpcTypes::AccountInfoWithBase64Data.new(
                executable: account_raw['executable'],
                lamports:   Kernel.Integer(account_raw['lamports']),
                owner:      account_raw['owner'],
                space:      Kernel.Integer(account_raw.fetch('space', 0)),
                rent_epoch: Kernel.Integer(account_raw.fetch('rentEpoch', 0)),
                data:       Kernel.Array(account_raw['data'])
              )
            }
          end
        end
      end
    end
  end
end
