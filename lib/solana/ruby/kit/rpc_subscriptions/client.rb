# typed: strict
# frozen_string_literal: true

require_relative 'transport'
require_relative 'subscription'
require_relative 'autopinger'
require_relative 'api/account_notifications'
require_relative 'api/logs_notifications'
require_relative 'api/program_notifications'
require_relative 'api/root_notifications'
require_relative 'api/signature_notifications'
require_relative 'api/slot_notifications'

module Solana::Ruby::Kit
  module RpcSubscriptions
    # WebSocket subscription client for Solana.
    # Mirrors TypeScript's createSolanaRpcSubscriptions(url) factory.
    #
    # @example
    #   subs = Solana::Ruby::Kit::RpcSubscriptions::Client.new('wss://api.devnet.solana.com')
    #   sub  = subs.slot_subscribe
    #   sub.take(3).each { |n| puts n.inspect }
    class Client
      extend T::Sig

      include Api::AccountNotifications
      include Api::LogsNotifications
      include Api::ProgramNotifications
      include Api::RootNotifications
      include Api::SignatureNotifications
      include Api::SlotNotifications

      sig { returns(Transport) }
      attr_reader :transport

      sig do
        params(
          url:           String,
          headers:       T::Hash[String, String],
          ping_interval: Float
        ).void
      end
      def initialize(url, headers: {}, ping_interval: 5.0)
        @transport  = T.let(Transport.new(url: url, headers: headers), Transport)
        @pinger     = T.let(Autopinger.new(@transport, interval: ping_interval), Autopinger)
        @pinger.start
      end

      sig { void }
      def close
        @pinger.stop
        @transport.close
      end

      private

      # Build a Subscription wrapping an AsyncIterable enumerator and
      # an auto-unsubscribe on close.
      sig { params(sub_id: T.untyped, unsub_method: String).returns(Subscription) }
      def _build_subscription(sub_id, unsub_method)
        publisher  = @transport.publisher
        enumerator = Subscribable::AsyncIterable.from_publisher(
          publisher,
          data_channel:  sub_id,
          error_channel: Subscribable::DataPublisher::ERROR_CHANNEL
        )

        unsubscribe = lambda do
          begin
            @transport.request(unsub_method, [sub_id])
          rescue StandardError
            nil # Best-effort: transport may already be closed
          end
        end

        Subscription.new(enumerator: enumerator, unsubscribe: unsubscribe)
      end
    end
  end
end
