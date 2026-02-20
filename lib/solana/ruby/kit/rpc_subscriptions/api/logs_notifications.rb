# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to transaction log notifications.
      # +filter+ may be 'all', 'allWithVotes', or { 'mentions' => [pubkey] }.
      module LogsNotifications
        extend T::Sig

        sig do
          params(
            filter:     T.untyped,
            commitment: T.nilable(Symbol)
          ).returns(Subscription)
        end
        def logs_subscribe(filter = 'all', commitment: nil)
          config = {}
          config['commitment'] = commitment.to_s if commitment

          sub_id = transport.request('logsSubscribe', config.empty? ? [filter] : [filter, config])
          _build_subscription(sub_id, 'logsUnsubscribe')
        end
      end
    end
  end
end
