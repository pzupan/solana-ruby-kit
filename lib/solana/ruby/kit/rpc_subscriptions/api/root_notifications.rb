# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to root change notifications.
      module RootNotifications
        extend T::Sig

        sig { returns(Subscription) }
        def root_subscribe
          sub_id = transport.request('rootSubscribe', [])
          _build_subscription(sub_id, 'rootUnsubscribe')
        end
      end
    end
  end
end
