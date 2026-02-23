#!/usr/bin/env ruby
# frozen_string_literal: true

# End-to-end example: create an Associated Token Account on Solana devnet.
#
# An Associated Token Account (ATA) is the canonical SPL-token balance account
# for a given (wallet, mint) pair.  Its address is a Program Derived Address so
# no keypair is needed — the program creates it from a known seed pattern.
#
# Algorithm:
#   1. Derive the ATA address (PDA) from wallet + mint
#   2. Build the createAssociatedTokenAccount instruction
#   3. Fetch a recent blockhash from the RPC
#   4. Build a legacy TransactionMessage via pipe()
#   5. Compile the message to wire bytes (compile_transaction_message)
#   6. Sign with the payer's key                   (sign_transaction)
#   7. Encode the full signed transaction          (wire_encode_transaction)
#   8. Submit to the cluster                       (send_transaction)
#
# Usage:
#   # Random payer (no real funds — works for ATA derivation demo only)
#   bundle exec ruby examples/create_ata.rb
#
#   # Real payer on devnet (request airdrop first)
#   PAYER_HEX="<64-byte keypair hex>" \
#   MINT_ADDRESS="<base58 mint>" \
#   RPC_URL="https://api.devnet.solana.com" \
#   bundle exec ruby examples/create_ata.rb

require 'base64'
require_relative '../lib/solana/ruby/kit'

Kit = Solana::Ruby::Kit

# ── Configuration ──────────────────────────────────────────────────────────────

RPC_URL      = ENV.fetch('RPC_URL', Kit::RpcTypes::DEVNET_URL)
MINT_ADDRESS = ENV.fetch('MINT_ADDRESS', '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU') # devnet USDC
SEND_TX      = ENV.fetch('SEND_TX', 'false') == 'true'

# Load payer from a 128-character hex string (64 raw bytes: seed || pubkey).
# If not supplied, a fresh random keypair is generated for demonstration.
payer_signer =
  if (hex = ENV['PAYER_HEX'])
    Kit::Signers.create_key_pair_signer_from_bytes([hex].pack('H*'))
  else
    puts '[demo] No PAYER_HEX supplied — generating a random keypair (cannot actually sign).'
    Kit::Signers.generate_key_pair_signer
  end

# ── Step 1: Derive ATA address ─────────────────────────────────────────────────

mint   = Kit::Addresses::Address.new(MINT_ADDRESS)
wallet = payer_signer.address

ata_pda = Kit::Programs::AssociatedTokenAccount.get_associated_token_address(
  wallet: wallet,
  mint:   mint
  # token_program_id: defaults to TOKEN_PROGRAM_ID (original SPL Token)
)

puts ''
puts "Wallet  : #{wallet}"
puts "Mint    : #{mint}"
puts "ATA     : #{ata_pda.address}  (bump #{ata_pda.bump})"
puts ''

# ── Step 2: Build the instruction ─────────────────────────────────────────────
#
# Using idempotent: true so the transaction succeeds even if the ATA already
# exists — safe for scripts that may be run more than once.

ix = Kit::Programs::AssociatedTokenAccount.create_instruction(
  payer:      wallet,
  wallet:     wallet,
  mint:       mint,
  idempotent: true
)

# ── Step 3: Fetch recent blockhash ─────────────────────────────────────────────

rpc = Kit::Rpc::Client.new(RPC_URL)

puts "Fetching latest blockhash from #{RPC_URL} …"
bh_resp = rpc.get_latest_blockhash

blockhash_constraint = Kit::TransactionMessages::BlockhashLifetimeConstraint.new(
  blockhash:               bh_resp.value.blockhash,
  last_valid_block_height: bh_resp.value.last_valid_block_height
)
puts "Blockhash: #{blockhash_constraint.blockhash}  (valid until block #{blockhash_constraint.last_valid_block_height})"
puts ''

# ── Step 4: Build the transaction message ──────────────────────────────────────
#
# Kit::Functional.pipe passes a value through a sequence of single-argument
# lambdas, mirroring TypeScript's `pipe()` from @solana/functional.

message = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: :legacy),
  ->(tx) { Kit::TransactionMessages.set_fee_payer(wallet, tx) },
  ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, tx) },
  ->(tx) { Kit::TransactionMessages.append_instructions(tx, [ix]) }
)

# ── Step 5: Compile to wire bytes ──────────────────────────────────────────────
#
# compile_transaction_message serialises the message into Solana's on-wire
# format and allocates a nil signature slot for every required signer.

transaction = Kit::Transactions.compile_transaction_message(message)

puts "Compiled message: #{transaction.message_bytes.bytesize} bytes"
puts "Required signers: #{transaction.signatures.keys.join(', ')}"
puts ''

# ── Step 6: Sign ───────────────────────────────────────────────────────────────

signed = Kit::Transactions.sign_transaction(
  [payer_signer.key_pair.signing_key],
  transaction
)

sig_hex = signed.signatures.values.first&.unpack1('H*')
puts "Payer signature (hex): #{sig_hex}"
puts ''

# ── Step 7 + 8: Encode full wire transaction and send (optional) ───────────────
#
# wire_encode_transaction prepends the compact-u16 signature count and the
# raw 64-byte signatures to the message bytes — this is what the RPC node
# expects as the `transaction` parameter of `sendTransaction`.
#
# sendTransaction accepts a String in which case it treats it as a
# pre-encoded base64 payload and sends it verbatim.

if SEND_TX
  wire_bytes  = Kit::Transactions.wire_encode_transaction(signed)
  wire_base64 = Base64.strict_encode64(wire_bytes)

  puts "Sending transaction (#{wire_bytes.bytesize} wire bytes) …"
  tx_signature = rpc.send_transaction(wire_base64, skip_preflight: false)

  puts ''
  puts "Success!"
  puts "Transaction signature : #{tx_signature}"
  puts "Explorer              : https://explorer.solana.com/tx/#{tx_signature}?cluster=devnet"
else
  puts '[SEND_TX=false] Skipping submission.  Set SEND_TX=true to broadcast.'
  wire_bytes = Kit::Transactions.wire_encode_transaction(signed)
  puts "Wire transaction (base64):"
  puts Base64.strict_encode64(wire_bytes)
end
