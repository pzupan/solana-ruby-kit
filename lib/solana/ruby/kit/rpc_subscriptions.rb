# typed: strict
# frozen_string_literal: true

# Mirrors @solana/rpc-subscriptions + @solana/rpc-subscriptions-api.
# Provides a WebSocket-based subscription client for Solana push notifications.
require_relative 'subscribable'
require_relative 'rpc_subscriptions/client'

module Solana::Ruby::Kit
  module RpcSubscriptions
  end
end
