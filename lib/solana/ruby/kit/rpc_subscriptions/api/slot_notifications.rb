# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to slot change notifications.
      module SlotNotifications
        extend T::Sig

        sig { returns(Subscription) }
        def slot_subscribe
          sub_id = transport.request('slotSubscribe', [])
          _build_subscription(sub_id, 'slotUnsubscribe')
        end
      end
    end
  end
end
