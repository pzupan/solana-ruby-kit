# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Returns the minimum balance required to keep an account rent-exempt
      # given its data size in bytes.
      # Mirrors `GetMinimumBalanceForRentExemptionApi.getMinimumBalanceForRentExemption()`.
      module GetMinimumBalanceForRentExemption
        extend T::Sig

        sig do
          params(
            data_size:  Integer,
            commitment: T.nilable(Symbol)
          ).returns(Integer)
        end
        def get_minimum_balance_for_rent_exemption(data_size, commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          params = config.empty? ? [data_size] : [data_size, config]
          Kernel.Integer(transport.request('getMinimumBalanceForRentExemption', params))
        end
      end
    end
  end
end
