# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    # Sends a WebSocket ping on a fixed interval to keep the connection alive.
    # Mirrors @solana/rpc-subscriptions autopinger.
    class Autopinger
      extend T::Sig

      sig { params(transport: Transport, interval: Float).void }
      def initialize(transport, interval: 5.0)
        @transport = transport
        @interval  = interval
        @thread    = T.let(nil, T.nilable(Thread))
      end

      sig { void }
      def start
        @thread = Thread.new do
          loop do
            sleep(@interval)
            break if @transport.publisher.closed?

            begin
              @transport.instance_variable_get(:@ws)&.send(nil, type: :ping)
            rescue StandardError
              break
            end
          end
        end
        @thread.abort_on_exception = false
      end

      sig { void }
      def stop
        @thread&.kill
        @thread = nil
      end
    end
  end
end
