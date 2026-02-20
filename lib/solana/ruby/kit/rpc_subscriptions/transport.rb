# typed: strict
# frozen_string_literal: true

require 'websocket-client-simple'
require 'json'
require 'thread'

module Solana::Ruby::Kit
  module RpcSubscriptions
    # WebSocket JSON-RPC transport for Solana subscription methods.
    # Runs in a background thread; dispatches incoming messages to a
    # DataPublisher keyed by subscription ID.
    #
    # Thread safety: all public methods are Mutex-protected.
    class Transport
      extend T::Sig

      # Channel name used for raw incoming messages (before routing to sub-ID).
      MESSAGE_CHANNEL = T.let(:__message__, Symbol)
      ERROR_CHANNEL   = T.let(:error, Symbol)
      CLOSE_CHANNEL   = T.let(:close, Symbol)

      sig { returns(String) }
      attr_reader :url

      sig do
        params(
          url:                         String,
          headers:                     T::Hash[String, String],
          send_buffer_high_watermark:  Integer
        ).void
      end
      def initialize(url:, headers: {}, send_buffer_high_watermark: 40)
        @url        = url
        @headers    = headers
        @hwm        = send_buffer_high_watermark
        @mutex      = T.let(Mutex.new, Mutex)
        @id_seq     = T.let(0, Integer)
        @pending     = T.let({}, T::Hash[Integer, Queue])   # request id → response Queue
        @subscribers = T.let(
          Hash.new { |h, k| h[k] = [] },
          T::Hash[T.untyped, T::Array[T.proc.params(msg: T::Hash[String, T.untyped]).void]]
        )
        @send_buffer  = T.let([], T::Array[String])
        @ws           = T.let(nil, T.nilable(WebSocket::Client::Simple::Client))
        @connected    = T.let(false, T::Boolean)
        @publisher    = T.let(Subscribable::DataPublisher.new, Subscribable::DataPublisher)

        _connect
      end

      # Send a JSON-RPC request and return the result synchronously (blocks).
      sig do
        params(method: String, params: T::Array[T.untyped])
          .returns(T.untyped)
      end
      def request(method, params = [])
        id     = _next_id
        q      = Queue.new
        @mutex.synchronize { @pending[id] = q }

        payload = JSON.generate({ 'jsonrpc' => '2.0', 'id' => id, 'method' => method, 'params' => params })
        _send(payload)

        response = q.pop
        raise Rpc::RpcError.new(response['error']['message'], response['error']['code']) if response['error']

        response['result']
      end

      # Subscribe to a channel (subscription ID from the server).
      # Returns an unsubscribe lambda.
      sig do
        params(
          sub_id: T.untyped,
          block:  T.proc.params(msg: T::Hash[String, T.untyped]).void
        ).returns(T.proc.void)
      end
      def subscribe(sub_id, &block)
        @mutex.synchronize { T.must(@subscribers[sub_id]) << block }
        lambda { @mutex.synchronize { T.must(@subscribers[sub_id]).delete(block) } }
      end

      # Access the underlying DataPublisher for AsyncIterable integration.
      sig { returns(Subscribable::DataPublisher) }
      attr_reader :publisher

      sig { void }
      def close
        @ws&.close
        @publisher.close
      end

      private

      sig { returns(Integer) }
      def _next_id
        @mutex.synchronize { @id_seq += 1; @id_seq }
      end

      sig { params(payload: String).void }
      def _send(payload)
        if @connected
          @ws&.send(payload)
        else
          @send_buffer << payload
        end
      end

      sig { void }
      def _connect # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        transport = self
        @ws = WebSocket::Client::Simple.connect(@url, headers: @headers)

        ws = @ws
        ws.on(:open) do
          transport.instance_variable_set(:@connected, true)
          transport.instance_variable_get(:@send_buffer).each { |m| ws.send(m) }
          transport.instance_variable_get(:@send_buffer).clear
        end

        ws.on(:message) do |msg|
          next unless msg.type == :text

          begin
            data = JSON.parse(msg.data)
          rescue JSON::ParserError
            next
          end

          if data.key?('id')
            # Response to a request
            id = data['id']
            q  = transport.instance_variable_get(:@mutex).synchronize do
              transport.instance_variable_get(:@pending).delete(id)
            end
            q&.push(data)
          elsif data.key?('method')
            # Push notification (subscription event)
            sub_id = data.dig('params', 'subscription')
            subs   = transport.instance_variable_get(:@mutex).synchronize do
              (transport.instance_variable_get(:@subscribers)[sub_id] || []).dup
            end
            subs.each { |blk| blk.call(data) }
            transport.instance_variable_get(:@publisher).publish(sub_id, data)
          end
        end

        ws.on(:error) do |e|
          transport.instance_variable_get(:@publisher).publish(
            Subscribable::DataPublisher::ERROR_CHANNEL,
            e.is_a?(StandardError) ? e : RuntimeError.new(e.to_s)
          )
        end

        ws.on(:close) do
          transport.instance_variable_set(:@connected, false)
          transport.instance_variable_get(:@publisher).close
        end
      end
    end
  end
end
