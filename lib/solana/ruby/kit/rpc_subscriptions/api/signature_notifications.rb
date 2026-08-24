# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to signature status notifications.
      # The subscription auto-unsubscribes once the signature is confirmed.
      module SignatureNotifications
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig do
          params(
            signature:  String,
            commitment: T.nilable(Symbol)
          ).returns(Subscription)
        end
        def signature_subscribe(signature, commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          sub_id = transport.request('signatureSubscribe', config.empty? ? [signature] : [signature, config])
          _build_subscription(sub_id, 'signatureUnsubscribe')
        end
      end
    end
  end
end
