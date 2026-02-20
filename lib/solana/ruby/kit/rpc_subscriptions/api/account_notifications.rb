# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to account change notifications.
      # Mirrors TypeScript's AccountNotificationsApi.accountSubscribe.
      module AccountNotifications
        extend T::Sig

        sig do
          params(
            pubkey:     String,
            commitment: T.nilable(Symbol),
            encoding:   String
          ).returns(Subscription)
        end
        def account_subscribe(pubkey, commitment: nil, encoding: 'base64')
          config = { 'encoding' => encoding }
          config['commitment'] = commitment.to_s if commitment

          sub_id = transport.request('accountSubscribe', [pubkey, config])
          _build_subscription(sub_id, 'accountUnsubscribe')
        end
      end
    end
  end
end
