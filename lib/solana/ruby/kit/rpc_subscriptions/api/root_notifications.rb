# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to root change notifications.
      module RootNotifications
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig { returns(Subscription) }
        def root_subscribe
          sub_id = transport.request('rootSubscribe', [])
          _build_subscription(sub_id, 'rootUnsubscribe')
        end
      end
    end
  end
end
