# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # One signature-level entry returned by getTransactionsForAddress when
      # `transaction_details` is `:signatures`.
      # Mirrors TypeScript's GetTransactionsForAddressSignature.
      TransactionsForAddressSignature = T.let(
        Struct.new(
          :block_time,          # Integer | nil — Unix timestamp of block production, nil if unavailable
          :confirmation_status, # Symbol | nil — :processed, :confirmed, or :finalized
          :err,                 # Hash | nil — transaction error, nil if succeeded
          :memo,                # String | nil — memo associated with the transaction
          :signature,           # String — base-58 encoded transaction signature
          :slot,                # Integer — slot containing the transaction
          :transaction_index,   # Integer — 0-based index within the block
          keyword_init: true
        ),
        T.untyped
      )

      # The result envelope shared by every mode of getTransactionsForAddress.
      #
      # `data` holds the matching transactions in the requested sort order. Its
      # element type depends on `transaction_details`: TransactionsForAddressSignature
      # structs for `:signatures`, and raw (String-keyed) response hashes for
      # `:full` — the same shape `Rpc::Api::GetTransaction#get_transaction`
      # returns, so each element can be handed straight to
      # `TransactionIntrospection.decode_transaction_from_rpc_response`.
      #
      # `pagination_token` is the cursor to pass back as `pagination_token` on a
      # subsequent call, or nil when there are no more results.
      #
      # Mirrors TypeScript's GetTransactionsForAddressApiResponse.
      TransactionsForAddressPage = T.let(
        Struct.new(
          :data,             # Array<TransactionsForAddressSignature> | Array<Hash>
          :pagination_token, # String | nil — cursor for the next page
          keyword_init: true
        ),
        T.untyped
      )

      # Returns confirmed transactions that load the given address, with
      # server-side filtering, sorting, and cursor-based pagination.
      #
      # This combines the discovery step of getSignaturesForAddress with
      # filtering and pagination the server applies itself. Note: check your RPC
      # provider for support for this method.
      #
      # Mirrors TypeScript's GetTransactionsForAddressApi.getTransactionsForAddress.
      # See https://solana.com/docs/rpc/http/gettransactionsforaddress
      module GetTransactionsForAddress
        extend T::Sig

        # Maps the snake_case keys of a Ruby +filters+ hash onto the wire names.
        # Comparison operators (:eq, :gt, :gte, :lt, :lte) pass through as-is.
        FILTER_KEYS = T.let(
          {
            block_time:     'blockTime',
            signature:      'signature',
            slot:           'slot',
            status:         'status',
            token_accounts: 'tokenAccounts'
          }.freeze,
          T::Hash[Symbol, String]
        )

        COMPARISON_KEYS = T.let(%i[eq gt gte lt lte].freeze, T::Array[Symbol])

        # @param address [String] base-58 address to search for.
        # @param transaction_details [Symbol] :signatures (default) or :full.
        # @param encoding [String, nil] 'base58', 'base64', 'json' (server default),
        #   or 'jsonParsed'. Only valid with `transaction_details: :full`.
        # @param max_supported_transaction_version [Integer, nil] newest transaction
        #   version to accept. Omit to receive only legacy transactions (in which
        #   case no `version` is returned). Only valid with `transaction_details: :full`.
        # @param commitment [Symbol, nil] :confirmed or :finalized. This method does
        #   not support :processed.
        # @param filters [Hash, nil] server-side filters, combined with AND. Supports
        #   `block_time:` ({eq/gt/gte/lt/lte}), `signature:` ({gt/gte/lt/lte}),
        #   `slot:` ({gt/gte/lt/lte}), `status:` (:any, :succeeded, :failed), and
        #   `token_accounts:` (:none, :balance_changed, :all).
        # @param limit [Integer, nil] max results. The server caps this at 1000 for
        #   `:signatures` and 100 for `:full`.
        # @param min_context_slot [Integer, nil] reject data older than this slot.
        # @param pagination_token [String, nil] cursor from a previous response's
        #   `pagination_token`, formatted "<slot>:<position>".
        # @param sort_order [Symbol, nil] :desc (newest first, server default) or :asc.
        # @return [TransactionsForAddressPage]
        sig do
          params(
            address:                            String,
            transaction_details:                Symbol,
            encoding:                           T.nilable(String),
            max_supported_transaction_version:  T.nilable(Integer),
            commitment:                         T.nilable(Symbol),
            filters:                            T.nilable(T::Hash[Symbol, T.untyped]),
            limit:                              T.nilable(Integer),
            min_context_slot:                   T.nilable(Integer),
            pagination_token:                   T.nilable(String),
            sort_order:                         T.nilable(Symbol)
          ).returns(T.untyped)
        end
        def get_transactions_for_address(
          address,
          transaction_details:               :signatures,
          encoding:                          nil,
          max_supported_transaction_version: nil,
          commitment:                        nil,
          filters:                           nil,
          limit:                             nil,
          min_context_slot:                  nil,
          pagination_token:                  nil,
          sort_order:                        nil
        )
          unless %i[signatures full].include?(transaction_details)
            Kernel.raise ArgumentError, "transaction_details must be :signatures or :full, got #{transaction_details.inspect}"
          end

          # The RPC rejects `processed` for this method; TypeScript encodes that
          # as `Exclude<Commitment, 'processed'>`, so fail fast here too.
          if commitment == :processed
            Kernel.raise ArgumentError, 'getTransactionsForAddress does not support the :processed commitment'
          end

          if transaction_details == :signatures
            if encoding
              Kernel.raise ArgumentError, 'encoding is only valid with transaction_details: :full'
            end
            if max_supported_transaction_version
              Kernel.raise ArgumentError, 'max_supported_transaction_version is only valid with transaction_details: :full'
            end
          end

          config = { 'transactionDetails' => transaction_details.to_s }
          config['encoding']                       = encoding if encoding
          config['maxSupportedTransactionVersion'] = max_supported_transaction_version if max_supported_transaction_version
          config['commitment']                     = commitment.to_s if commitment
          config['limit']                          = limit if limit
          config['minContextSlot']                 = min_context_slot if min_context_slot
          config['paginationToken']                = pagination_token if pagination_token
          config['sortOrder']                      = sort_order.to_s if sort_order
          config['filters']                        = build_filters(filters) if filters && !filters.empty?

          raw  = transport.request('getTransactionsForAddress', [address, config])
          rows = raw['data'] || []

          data = if transaction_details == :full
                   # Returned verbatim so each element can be fed to
                   # TransactionIntrospection.decode_transaction_from_rpc_response.
                   rows
                 else
                   rows.map do |tx|
                     TransactionsForAddressSignature.new(
                       block_time:          tx['blockTime'],
                       confirmation_status: tx['confirmationStatus']&.to_sym,
                       err:                 tx['err'],
                       memo:                tx['memo'],
                       signature:           tx['signature'],
                       slot:                Kernel.Integer(tx['slot']),
                       transaction_index:   tx['transactionIndex'] && Kernel.Integer(tx['transactionIndex'])
                     )
                   end
                 end

          TransactionsForAddressPage.new(data: data, pagination_token: raw['paginationToken'])
        end

        # ── Private helpers ────────────────────────────────────────────────────

        # Converts the snake_case +filters+ hash into its wire form. Symbol values
        # (`status`, `token_accounts`) are lowerCamelCased so `:balance_changed`
        # reaches the server as `"balanceChanged"`.
        sig { params(filters: T::Hash[Symbol, T.untyped]).returns(T::Hash[String, T.untyped]) }
        def build_filters(filters)
          filters.each_with_object({}) do |(key, value), out|
            wire_key = FILTER_KEYS[key]
            Kernel.raise ArgumentError, "unknown filter #{key.inspect}" if wire_key.nil?

            out[wire_key] = if value.is_a?(Hash)
                              value.each_with_object({}) do |(op, operand), cmp|
                                unless COMPARISON_KEYS.include?(op)
                                  Kernel.raise ArgumentError, "unknown comparison #{op.inspect} in filter #{key.inspect}"
                                end
                                cmp[op.to_s] = operand
                              end
                            elsif value.is_a?(Symbol)
                              camelize(value)
                            else
                              value
                            end
          end
        end
        private :build_filters

        sig { params(value: Symbol).returns(String) }
        def camelize(value)
          head, *rest = value.to_s.split('_')
          ([head] + rest.map(&:capitalize)).join
        end
        private :camelize
      end
    end
  end
end
