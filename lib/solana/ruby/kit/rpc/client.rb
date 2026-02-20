# typed: strict
# frozen_string_literal: true

require_relative 'transport'
require_relative 'api/get_slot'
require_relative 'api/get_balance'
require_relative 'api/get_latest_blockhash'
require_relative 'api/get_account_info'
require_relative 'api/get_block_height'
require_relative 'api/get_signature_statuses'
require_relative 'api/send_transaction'
require_relative 'api/request_airdrop'
require_relative 'api/is_blockhash_valid'
require_relative 'api/get_minimum_balance_for_rent_exemption'
require_relative 'api/get_multiple_accounts'
require_relative 'api/get_program_accounts'
require_relative 'api/get_transaction'
require_relative 'api/get_token_account_balance'
require_relative 'api/get_token_accounts_by_owner'
require_relative 'api/get_epoch_info'
require_relative 'api/get_vote_accounts'
require_relative 'api/simulate_transaction'

module Solana::Ruby::Kit
  module Rpc
    # Solana JSON-RPC client.
    # Mirrors TypeScript's `Rpc` object created by `createSolanaRpc(url)`.
    #
    # Includes every API method as a mixin so the class surface exactly matches
    # the TypeScript package's method set.  The `transport` accessor provides
    # sub-modules with the HTTP connection.
    #
    # @example
    #   rpc  = Solana::Ruby::Kit::Rpc::Client.new(Solana::Ruby::Kit::RpcTypes.devnet)
    #   slot = rpc.get_slot
    #   res  = rpc.get_balance(address)
    #   puts "#{res.value} lamports at slot #{res.slot}"
    class Client
      extend T::Sig

      include Api::GetSlot
      include Api::GetBalance
      include Api::GetLatestBlockhash
      include Api::GetAccountInfo
      include Api::GetBlockHeight
      include Api::GetSignatureStatuses
      include Api::SendTransaction
      include Api::RequestAirdrop
      include Api::IsBlockhashValid
      include Api::GetMinimumBalanceForRentExemption
      include Api::GetMultipleAccounts
      include Api::GetProgramAccounts
      include Api::GetTransaction
      include Api::GetTokenAccountBalance
      include Api::GetTokenAccountsByOwner
      include Api::GetEpochInfo
      include Api::GetVoteAccounts
      include Api::SimulateTransaction

      sig { returns(Transport) }
      attr_reader :transport

      # @param cluster_url [RpcTypes::ClusterUrl, String]  endpoint to connect to.
      # @param headers     [Hash<String, String>]           additional HTTP headers.
      # @param timeout     [Integer]                        read timeout in seconds.
      sig do
        params(
          cluster_url:  T.untyped,    # RpcTypes::ClusterUrl or String
          headers:      T::Hash[String, String],
          timeout:      Integer,
          open_timeout: Integer
        ).void
      end
      def initialize(cluster_url, headers: {}, timeout: Transport::DEFAULT_TIMEOUT, open_timeout: Transport::DEFAULT_OPEN_TIMEOUT)
        url = cluster_url.respond_to?(:url) ? cluster_url.url : cluster_url.to_s
        @transport = T.let(
          Transport.new(url: url, headers: headers, timeout: timeout, open_timeout: open_timeout),
          Transport
        )
      end
    end
  end
end
