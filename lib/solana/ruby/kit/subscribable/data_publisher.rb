# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Subscribable
    # Thread-safe pub/sub hub — mirrors @solana/subscribable DataPublisher.
    #
    # Channels are arbitrary symbols/strings.  Subscribers are blocks called
    # synchronously from #publish (in the calling thread).  An optional
    # +signal+ lambda is checked before each dispatch; if it raises the
    # subscriber is automatically removed.
    #
    # Returns an unsubscribe lambda from #on.
    class DataPublisher
      extend T::Sig

      ERROR_CHANNEL = T.let(:error, Symbol)
      CLOSE_CHANNEL = T.let(:close, Symbol)

      sig { void }
      def initialize
        # channel_name → [[subscriber_proc, signal_lambda_or_nil], ...]
        @subscribers = T.let(
          Hash.new { |h, k| h[k] = [] },
          T::Hash[T.untyped, T::Array[[T.proc.params(data: T.untyped).void, T.nilable(T.proc.void)]]]
        )
        @mutex  = T.let(Mutex.new, Mutex)
        @closed = T.let(false, T::Boolean)
      end

      # Register +block+ as a subscriber on +channel_name+.
      # +signal+ is an optional lambda that is called before each dispatch;
      # if it raises (e.g. a Timeout::Error or custom AbortError) the
      # subscription is removed automatically.
      # Returns a lambda that removes the subscription when called.
      sig do
        params(
          channel_name: T.untyped,
          signal:       T.nilable(T.proc.void),
          block:        T.proc.params(data: T.untyped).void
        ).returns(T.proc.void)
      end
      def on(channel_name, signal: nil, &block)
        entry = [block, signal]
        @mutex.synchronize { T.must(@subscribers[channel_name]) << entry }

        # Return unsubscribe lambda
        lambda do
          @mutex.synchronize { T.must(@subscribers[channel_name]).delete(entry) }
        end
      end

      # Deliver +data+ to all subscribers on +channel_name+.
      # Subscribers whose signal has fired are pruned automatically.
      sig { params(channel_name: T.untyped, data: T.untyped).void }
      def publish(channel_name, data)
        entries = @mutex.synchronize { (@subscribers[channel_name] || []).dup }
        entries.each do |subscriber, signal|
          begin
            signal&.call
          rescue StandardError
            # Signal fired — remove this subscriber and skip dispatch
            @mutex.synchronize { T.must(@subscribers[channel_name]).delete([subscriber, signal]) }
            next
          end
          begin
            subscriber.call(data)
          rescue StandardError => e
            # Dispatch errors are re-published on the error channel (not raised)
            publish(ERROR_CHANNEL, e) unless channel_name == ERROR_CHANNEL
          end
        end
      end

      # Close the publisher: emit a final event on the close channel and remove
      # all subscribers.
      sig { void }
      def close
        publish(CLOSE_CHANNEL, nil)
        @mutex.synchronize do
          @subscribers.clear
          @closed = true
        end
      end

      sig { returns(T::Boolean) }
      def closed? = @closed
    end
  end
end
