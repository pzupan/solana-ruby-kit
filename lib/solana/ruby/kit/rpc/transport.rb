# typed: strict
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative '../errors'

module Solana::Ruby::Kit
  module Rpc
    # JSON-RPC error returned by the Solana node.
    class RpcError < StandardError
      extend T::Sig

      sig { returns(Integer) }
      attr_reader :code

      sig { returns(T.untyped) }
      attr_reader :data

      sig { params(code: Integer, message: String, data: T.untyped).void }
      def initialize(code, message, data = nil)
        @code = T.let(code, Integer)
        @data = T.let(data, T.untyped)
        super("JSON-RPC error #{code}: #{message}")
      end
    end

    # HTTP error from the transport layer (non-2xx response).
    class HttpTransportError < StandardError
      extend T::Sig

      sig { returns(Integer) }
      attr_reader :status_code

      sig { params(status_code: Integer, message: String).void }
      def initialize(status_code, message)
        @status_code = T.let(status_code, Integer)
        super("HTTP #{status_code}: #{message}")
      end
    end

    # HTTP transport for Solana's JSON-RPC API.
    # Mirrors TypeScript's `createHttpTransport(config)` from @solana/rpc-transport-http.
    #
    # Makes synchronous POST requests — TypeScript's async `fetch` maps to
    # Ruby's blocking `Net::HTTP`.  Use threads or Fibers for concurrency.
    class Transport
      extend T::Sig

      DEFAULT_TIMEOUT   = T.let(30, Integer)   # seconds
      DEFAULT_OPEN_TIMEOUT = T.let(10, Integer) # seconds

      sig { returns(String) }
      attr_reader :url

      sig do
        params(
          url:            String,
          headers:        T::Hash[String, String],
          timeout:        Integer,
          open_timeout:   Integer,
          to_json:        T.nilable(T.proc.params(arg0: T.untyped).returns(String)),
          from_json:      T.nilable(T.proc.params(arg0: String, arg1: T.untyped).returns(T.untyped))
        ).void
      end
      def initialize(
        url:,
        headers:      {},
        timeout:      DEFAULT_TIMEOUT,
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        to_json:      nil,
        from_json:    nil
      )
        @url          = T.let(url, String)
        @headers      = T.let(headers, T::Hash[String, String])
        @timeout      = T.let(timeout, Integer)
        @open_timeout = T.let(open_timeout, Integer)
        @to_json      = T.let(to_json, T.nilable(T.proc.params(arg0: T.untyped).returns(String)))
        @from_json    = T.let(from_json, T.nilable(T.proc.params(arg0: String, arg1: T.untyped).returns(T.untyped)))
        @request_id   = T.let(0, Integer)
        @uri          = T.let(URI.parse(url), URI::Generic)
      end

      # Sends a single JSON-RPC request and returns the parsed `result`.
      # Raises `RpcError` on a JSON-RPC error, `HttpTransportError` on HTTP failure.
      sig { params(method: String, params: T::Array[T.untyped]).returns(T.untyped) }
      def request(method, params = [])
        payload = build_payload(method, params)
        body    = @to_json ? @to_json.call(payload) : JSON.generate(payload)

        response = post(body)

        parsed = @from_json ? @from_json.call(T.must(response.body), payload) : JSON.parse(T.must(response.body))

        if parsed.key?('error')
          err = parsed['error']
          raise RpcError.new(err['code'].to_i, err['message'].to_s, err['data'])
        end

        parsed['result']
      end

      private

      sig { params(method: String, params: T::Array[T.untyped]).returns(T::Hash[String, T.untyped]) }
      def build_payload(method, params)
        @request_id += 1
        { 'jsonrpc' => '2.0', 'id' => @request_id, 'method' => method, 'params' => params }
      end

      sig { params(body: String).returns(Net::HTTPResponse) }
      def post(body)
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl      = (@uri.scheme == 'https')
        http.read_timeout = @timeout
        http.open_timeout = @open_timeout

        req = Net::HTTP::Post.new(T.cast(@uri, URI::HTTP).request_uri)
        req['Content-Type']   = 'application/json; charset=utf-8'
        req['Accept']         = 'application/json'
        req['Content-Length'] = body.bytesize.to_s
        req['solana-client']  = 'ruby-kit'
        @headers.each { |k, v| req[k] = v }
        req.body = body

        response = http.request(req)

        unless response.is_a?(Net::HTTPSuccess)
          raise HttpTransportError.new(response.code.to_i, response.message)
        end

        response
      end
    end
  end
end
