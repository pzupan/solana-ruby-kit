# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Subscribe to program account change notifications.
      module ProgramNotifications
        extend T::Sig

        sig do
          params(
            program_id:  String,
            commitment:  T.nilable(Symbol),
            encoding:    String,
            filters:     T::Array[T::Hash[String, T.untyped]]
          ).returns(Subscription)
        end
        def program_subscribe(program_id, commitment: nil, encoding: 'base64', filters: [])
          config = { 'encoding' => encoding }
          config['commitment'] = commitment.to_s if commitment
          config['filters']    = filters unless filters.empty?

          sub_id = transport.request('programSubscribe', [program_id, config])
          _build_subscription(sub_id, 'programUnsubscribe')
        end
      end
    end
  end
end
