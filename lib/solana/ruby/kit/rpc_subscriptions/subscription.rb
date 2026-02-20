# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    # A live subscription to a Solana WebSocket notification channel.
    # Wraps a DataPublisher channel and exposes an Enumerator interface.
    #
    # Typical usage:
    #   sub = client.slot_subscribe
    #   sub.take(10).each { |notification| puts notification }
    #   sub.unsubscribe  # or break from the enumerator loop
    class Subscription
      extend T::Sig
      extend T::Generic

      Elem = type_member { { fixed: T.untyped } }

      sig { returns(T::Enumerator[T.untyped]) }
      attr_reader :enumerator

      sig do
        params(
          enumerator:    T::Enumerator[T.untyped],
          unsubscribe:   T.proc.void,
          timeout:       T.nilable(Float)
        ).void
      end
      def initialize(enumerator:, unsubscribe:, timeout: nil)
        @enumerator  = enumerator
        @unsubscribe = unsubscribe
        @timeout     = timeout
      end

      # Stop the subscription and clean up.
      sig { void }
      def unsubscribe
        @unsubscribe.call
      end

      # Delegate Enumerable methods to the enumerator for convenience.
      sig { override.params(block: T.proc.params(item: T.untyped).void).void }
      def each(&block)
        @enumerator.each(&block)
      ensure
        unsubscribe
      end

      sig { params(n: Integer).returns(T::Array[T.untyped]) }
      def take(n) = @enumerator.take(n)

      sig { returns(T.untyped) }
      def next = @enumerator.next

      include Enumerable
    end
  end
end
