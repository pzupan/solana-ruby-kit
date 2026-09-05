#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: fetch the Alpenglow genesis certificate from an RPC node.
#
# Alpenglow is Solana's new consensus protocol.  When a cluster activates it,
# the switchover is recorded by a "genesis certificate" — an aggregate BLS
# signature from the validator set attesting to the specific block at which the
# protocol took effect.  Nodes gossip it between themselves; `getAgGenesisCert`
# exposes whatever the node you ask happens to hold.
#
# The response mirrors the validator's `WireBlockCertMessage`:
#
#   cert.block.slot            Integer      — slot of the certified block
#   cert.block.block_id        Array<Integer> — 32-byte block id
#   cert.signature.signature   Array<Integer> — 192-byte aggregate BLS signature
#   cert.signature.bitmap      Array<Integer> — which validators are in the aggregate
#
# Three outcomes are worth distinguishing, and this example handles all of them:
#
#   1. A certificate is returned — the cluster has activated Alpenglow.
#   2. `nil` is returned         — the node is healthy but has no certificate,
#                                  which is the normal answer on a cluster that
#                                  has not activated Alpenglow yet.
#   3. RpcError -32601           — the node is too old to know the method at all.
#                                  Expect this from most public endpoints today.
#
# Usage:
#   bundle exec ruby examples/get_ag_genesis_cert.rb
#
#   RPC_URL="https://api.testnet.solana.com" \
#   bundle exec ruby examples/get_ag_genesis_cert.rb

require_relative '../lib/solana/ruby/kit'

Kit = Solana::Ruby::Kit

# ── Configuration ──────────────────────────────────────────────────────────────

RPC_URL = ENV.fetch('RPC_URL', Kit::RpcTypes::DEVNET_URL)

# ── Fetch the certificate ──────────────────────────────────────────────────────

rpc = Kit::Rpc::Client.new(RPC_URL)

puts ''
puts "Requesting the Alpenglow genesis certificate from #{RPC_URL} …"
puts ''

begin
  cert = rpc.get_ag_genesis_cert
rescue Kit::Rpc::RpcError => e
  # -32601 is JSON-RPC's "method not found": this node predates getAgGenesisCert.
  if e.code == -32601
    puts "This node does not implement getAgGenesisCert (JSON-RPC -32601)."
    puts 'It is running a validator version from before the method was added.'
    exit 0
  end

  raise
end

# ── Report ─────────────────────────────────────────────────────────────────────

if cert.nil?
  puts 'No genesis certificate.'
  puts ''
  puts 'The node answered normally but holds no certificate — the expected result'
  puts 'on a cluster that has not activated Alpenglow, or on a node that has not'
  puts 'yet received the certificate over gossip.'
  exit 0
end

# Both byte fields arrive as arrays of integers rather than as a base58 string or
# a binary payload, so render them as hex to get something comparable by eye.
block_id_hex  = cert.block.block_id.map { |b| format('%02x', b) }.join
signature_hex = cert.signature.signature.map { |b| format('%02x', b) }.join

puts 'Alpenglow genesis certificate found.'
puts ''
puts "Certified slot     : #{cert.block.slot}"
puts "Block id           : #{block_id_hex}  (#{cert.block.block_id.length} bytes)"
puts "Aggregate signature: #{signature_hex}  (#{cert.signature.signature.length} bytes)"
puts ''

# The bitmap says which validators, by rank, are represented in the aggregate
# signature — one bit each, so its population count is the number of signers.
signer_count = cert.signature.bitmap.sum { |byte| byte.to_s(2).count('1') }

puts "Signer bitmap      : #{cert.signature.bitmap.length} bytes, #{signer_count} validators signed"
puts "Explorer           : https://explorer.solana.com/block/#{cert.block.slot}"
