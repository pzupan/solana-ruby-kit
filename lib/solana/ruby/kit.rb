# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'kit/version'
require_relative 'kit/configuration'

# ── Foundational utilities ────────────────────────────────────────────────────
require_relative 'kit/errors'
require_relative 'kit/encoding/base58'
require_relative 'kit/functional'
require_relative 'kit/options'
require_relative 'kit/fast_stable_stringify'
require_relative 'kit/promises'

# ── Cryptography: addresses & keys ───────────────────────────────────────────
require_relative 'kit/addresses'
require_relative 'kit/keys'

# ── On-chain data model ──────────────────────────────────────────────────────
require_relative 'kit/accounts'
require_relative 'kit/instructions'

# ── Transaction pipeline ─────────────────────────────────────────────────────
require_relative 'kit/transaction_messages'
require_relative 'kit/transactions'
require_relative 'kit/signers'

# ── Network / RPC ─────────────────────────────────────────────────────────────
require_relative 'kit/rpc_types'
require_relative 'kit/rpc'
require_relative 'kit/rpc_parsed_types'

# ── Codec system ─────────────────────────────────────────────────────────────
require_relative 'kit/codecs'

# ── Pub/sub + WebSocket subscriptions ────────────────────────────────────────
require_relative 'kit/subscribable'
require_relative 'kit/rpc_subscriptions'

# ── Plugin system ─────────────────────────────────────────────────────────────
require_relative 'kit/plugin_core'

# ── Higher-level helpers ──────────────────────────────────────────────────────
require_relative 'kit/offchain_messages'
require_relative 'kit/programs'
require_relative 'kit/sysvars'
require_relative 'kit/transaction_confirmation'
require_relative 'kit/instruction_plans'

# Solana::Ruby::Kit is a Ruby translation of @anza-xyz/kit — the JavaScript SDK for
# building Solana apps — into idiomatic Ruby with Sorbet static types.
#
# Translated packages:
#   Solana::Ruby::Kit::Functional            — pipe()                  (@solana/functional)
#   Solana::Ruby::Kit::Options               — Some/None/Option         (@solana/options)
#   Solana::Ruby::Kit::Addresses             — address validation       (@solana/addresses)
#   Solana::Ruby::Kit::Keys                  — Ed25519 keys             (@solana/keys)
#   Solana::Ruby::Kit::Accounts              — account structs          (@solana/accounts)
#   Solana::Ruby::Kit::Instructions          — instruction types        (@solana/instructions)
#   Solana::Ruby::Kit::TransactionMessages   — message builder          (@solana/transaction-messages)
#   Solana::Ruby::Kit::Transactions          — signing + wire TX        (@solana/transactions)
#   Solana::Ruby::Kit::Signers               — KeyPairSigner            (@solana/signers)
#   Solana::Ruby::Kit::RpcTypes              — types + cluster URLs     (@solana/rpc-types)
#   Solana::Ruby::Kit::Rpc                   — JSON-RPC client          (@solana/rpc)
#   Solana::Ruby::Kit::RpcParsedTypes        — jsonParsed structs       (@solana/rpc-parsed-types)
#   Solana::Ruby::Kit::FastStableStringify   — deterministic JSON       (@solana/fast-stable-stringify)
#   Solana::Ruby::Kit::Promises              — safe_race + with_timeout (@solana/promises)
#   Solana::Ruby::Kit::Codecs                — Encoder/Decoder codecs   (@solana/codecs)
#   Solana::Ruby::Kit::Subscribable          — DataPublisher + Enum.    (@solana/subscribable)
#   Solana::Ruby::Kit::RpcSubscriptions      — WebSocket subscriptions  (@solana/rpc-subscriptions)
#   Solana::Ruby::Kit::PluginCore            — plugin client builder    (@solana/rpc-types plugin)
#   Solana::Ruby::Kit::OffchainMessages      — off-chain signing        (@solana/signers)
#   Solana::Ruby::Kit::Programs              — program error helpers    (@solana/programs)
#   Solana::Ruby::Kit::Sysvars               — sysvar fetch/decode      (@solana/sysvars)
#   Solana::Ruby::Kit::TransactionConfirmation — confirmation polling   (@solana/transaction-confirmation)
#   Solana::Ruby::Kit::InstructionPlans      — multi-tx planning        (@solana/instruction-plans)

module Solana::Ruby::Kit
  extend T::Sig

  @configuration = T.let(Configuration.new, Configuration)

  sig { returns(Configuration) }
  def self.configuration
    @configuration
  end

  sig { params(block: T.proc.params(arg0: Configuration).void).void }
  def self.configure(&block)
    block.call(@configuration)
  end

  sig { returns(Rpc::Client) }
  def self.rpc_client
    Rpc::Client.new(configuration.rpc_url)
  end
end

require_relative 'kit/railtie' if defined?(Rails::Railtie)
