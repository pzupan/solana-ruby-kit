# solana-ruby-kit

A Ruby port of [@anza-xyz/kit](https://github.com/anza-xyz/kit) — the official Solana TypeScript SDK — translated into idiomatic Ruby with [Sorbet](https://sorbet.org) static types.

Every module maps 1-to-1 to a TypeScript package. All methods are synchronous (Ruby's RbNaCl is synchronous; TypeScript's Web Crypto API is not).

## Requirements

- Ruby >= 3.2
- libsodium (required by `rbnacl`)

```bash
# macOS
brew install libsodium

# Debian / Ubuntu
apt-get install libsodium-dev
```

## Installation

```ruby
# Gemfile
gem 'solana-ruby-kit'
```

```bash
bundle install
```

## Quick start

```ruby
require 'solana/ruby/kit'

Kit = Solana::Ruby::Kit

# Generate a signer
signer = Kit::Signers.generate_key_pair_signer
puts signer.address   # => base58 public key

# Connect to devnet
rpc = Kit::Rpc::Client.new(Kit::RpcTypes.devnet)
puts rpc.get_slot     # => 123456789

# Build and send a transaction
blockhash_resp = rpc.get_latest_blockhash
constraint = Kit::TransactionMessages::BlockhashLifetimeConstraint.new(
  blockhash:               blockhash_resp.value.blockhash,
  last_valid_block_height: blockhash_resp.value.last_valid_block_height
)

msg = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: 0),
  ->(tx) { Kit::TransactionMessages.set_fee_payer(signer.address, tx) },
  ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(constraint, tx) }
)
```

## Create a wallet

Generating a keypair creates the wallet **locally**. The wallet only exists **on-chain** once it receives SOL — Solana allocates account storage at that point. On devnet you can fund it with an airdrop; on mainnet someone must send SOL to the address.

```ruby
require 'solana/ruby/kit'

Kit = Solana::Ruby::Kit

# ── 1. Generate the keypair (local only, not yet on-chain) ────────────────────

signer = Kit::Signers.generate_key_pair_signer
puts "Address: #{signer.address}"

# ── 2. Save to disk ───────────────────────────────────────────────────────────
# Standard format: 64 raw bytes = 32-byte private seed || 32-byte public key.
# Compatible with `solana-keygen new` and Phantom's export format.

kp        = signer.key_pair
raw_bytes = kp.signing_key.to_bytes + kp.verify_key.to_bytes
File.binwrite('wallet.bin', raw_bytes)

# ── 3. Fund the wallet on-chain (devnet / testnet only) ───────────────────────
# request_airdrop is the System Program creating the account and crediting SOL.
# On mainnet, skip this and have another wallet send SOL to signer.address instead.

rpc = Kit::Rpc::Client.new(Kit::RpcTypes.devnet)

airdrop_sig = rpc.request_airdrop(signer.address.to_s, 1_000_000_000) # 1 SOL in lamports
puts "Airdrop signature: #{airdrop_sig}"

# ── 4. Wait for the airdrop transaction to confirm ────────────────────────────

Kit::TransactionConfirmation.wait_for_confirmation(
  rpc,
  airdrop_sig,
  commitment:   :confirmed,
  timeout_secs: 30
)
puts "Confirmed."

# ── 5. Verify the account exists on-chain ─────────────────────────────────────

balance = rpc.get_balance(signer.address)
puts "Balance: #{balance.value / 1_000_000_000.0} SOL"   # => "1.0 SOL"

# ── Load from disk later ──────────────────────────────────────────────────────

loaded = Kit::Signers.create_key_pair_signer_from_bytes(File.binread('wallet.bin'))
puts loaded.address  # same address
```

## Transfer SOL from one wallet to another

```ruby
require 'base64'
require 'solana/ruby/kit'

Kit = Solana::Ruby::Kit

# ── 1. Load your sender keypair ───────────────────────────────────────────────────
sender = Kit::Signers.create_key_pair_signer_from_bytes(File.binread('wallet.bin'))

recipient = Kit::Addresses.address('RECIPIENT_ADDRESS_HERE')

# ── 2. Build the transfer instruction (0.5 SOL) ───────────────────────────────────
ix = Kit::Programs::SystemProgram.transfer_instruction(
  sender:    sender.address,
  recipient: recipient,
  lamports:  500_000_000
)

# ── 2. Fetch blockhash, build message, compile, sign, send ───────────────────────────────────
rpc = Kit::Rpc::Client.new(Kit::RpcTypes.devnet)
bh  = rpc.get_latest_blockhash

message = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: :legacy),
  ->(tx) { Kit::TransactionMessages.set_fee_payer(sender.address, tx) },
  ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(
    Kit::TransactionMessages::BlockhashLifetimeConstraint.new(
      blockhash: bh.value.blockhash, last_valid_block_height: bh.value.last_valid_block_height
    ), tx) },
  ->(tx) { Kit::TransactionMessages.append_instructions(tx, [ix]) }
)

transaction = Kit::Transactions.compile_transaction_message(message)
signed      = Kit::Transactions.sign_transaction([sender.key_pair.signing_key], transaction)
wire_base64 = Base64.strict_encode64(Kit::Transactions.wire_encode_transaction(signed))

sig = rpc.send_transaction(wire_base64)
puts "Signature: #{sig}"
```

## Create an Associated Token Account

A complete example showing how to create an SPL token account for a wallet. The ATA address is deterministic — derived from the wallet + mint — so no extra keypair is needed.

```ruby
require 'base64'
require 'solana/ruby/kit'

Kit = Solana::Ruby::Kit

# ── 1. Signer and addresses ───────────────────────────────────────────────────

# Load your payer from 64 raw bytes (seed || public key).
# Replace File.binread with however you store your keypair.
payer = Kit::Signers.create_key_pair_signer_from_bytes(File.binread('wallet.bin'))

mint = Kit::Addresses.address('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v') # USDC

# ── 2. Build the instruction ──────────────────────────────────────────────────
# create_instruction derives the ATA address internally. Passing idempotent: true
# means the transaction succeeds even if the ATA already exists.

ix = Kit::Programs::AssociatedTokenAccount.create_instruction(
  payer:      payer.address,
  wallet:     payer.address,
  mint:       mint,
  idempotent: true
)

# The derived ATA address is the second account in the instruction.
puts "ATA address : #{ix.accounts[1].address}"

# ── 3. Fetch a recent blockhash ───────────────────────────────────────────────

rpc = Kit::Rpc::Client.new(Kit::RpcTypes.mainnet)

bh = rpc.get_latest_blockhash
constraint = Kit::TransactionMessages::BlockhashLifetimeConstraint.new(
  blockhash:               bh.value.blockhash,
  last_valid_block_height: bh.value.last_valid_block_height
)

# ── 4. Build the transaction message ─────────────────────────────────────────

message = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: :legacy),
  ->(tx) { Kit::TransactionMessages.set_fee_payer(payer.address, tx) },
  ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(constraint, tx) },
  ->(tx) { Kit::TransactionMessages.append_instructions(tx, [ix]) }
)

# ── 5. Compile → sign → encode → send ────────────────────────────────────────

# compile_transaction_message serialises the message into Solana's on-wire
# format and reserves a nil signature slot for every required signer.
transaction = Kit::Transactions.compile_transaction_message(message)

# sign_transaction fills every slot and raises if any signer is missing.
signed = Kit::Transactions.sign_transaction(
  [payer.key_pair.signing_key],
  transaction
)

# wire_encode_transaction prepends the compact-u16 signature count + raw
# 64-byte signatures to the message bytes — the full payload for sendTransaction.
wire_base64 = Base64.strict_encode64(
  Kit::Transactions.wire_encode_transaction(signed)
)

signature = rpc.send_transaction(wire_base64, skip_preflight: false)
puts "Transaction signature: #{signature}"
```

## Stake SOL with a validator

A complete example that creates a new stake account, funds it, and delegates it to a validator — all in two transactions. The first transaction allocates and initialises the account; the second delegates it once the first has confirmed.

```ruby
require 'base64'
require 'solana/ruby/kit'

Kit   = Solana::Ruby::Kit
Stake = Kit::Programs::StakeProgram
TxMsg = Kit::TransactionMessages
Txns  = Kit::Transactions

rpc = Kit::Rpc::Client.new(Kit::RpcTypes.devnet)

# ── 1. Signers ────────────────────────────────────────────────────────────────
# Your funding wallet — pays rent and signs as the fee payer.
owner = Kit::Signers.create_key_pair_signer_from_bytes(File.binread('wallet.bin'))

# A fresh keypair for the stake account itself (must sign the createAccount ix).
stake_keypair = Kit::Signers.generate_key_pair_signer

# The validator you want to delegate to (look this up via get_vote_accounts).
vote_address = Kit::Addresses.address('VALIDATOR_VOTE_ADDRESS_HERE')

# ── 2. How many lamports to stake? ────────────────────────────────────────────
# The account must be rent-exempt (200 bytes) plus however much you want to stake.
rent_exempt = rpc.get_minimum_balance_for_rent_exemption(Stake::STAKE_ACCOUNT_SPACE)
stake_amount = 500_000_000    # 0.5 SOL on top of rent exemption
lamports = rent_exempt + stake_amount

# ── 3. Build the first transaction: create + initialise the stake account ──────
create_ixs = Stake.create_account_instructions(
  from:          owner.address,
  stake_account: stake_keypair.address,
  authorized:    owner.address,   # owner is both staker and withdrawer
  lamports:      lamports
)

bh = rpc.get_latest_blockhash
constraint = TxMsg::BlockhashLifetimeConstraint.new(
  blockhash:               bh.value.blockhash,
  last_valid_block_height: bh.value.last_valid_block_height
)

create_msg = Kit::Functional.pipe(
  TxMsg.create_transaction_message(version: :legacy),
  ->(tx) { TxMsg.set_fee_payer(owner.address, tx) },
  ->(tx) { TxMsg.set_blockhash_lifetime(constraint, tx) },
  ->(tx) { TxMsg.append_instructions(tx, create_ixs) }
)

create_tx = Txns.compile_transaction_message(create_msg)

# Both owner and stake_keypair must sign: owner funds the account,
# stake_keypair authorises the createAccount on its own address.
create_signed = Txns.sign_transaction(
  [owner.key_pair.signing_key, stake_keypair.key_pair.signing_key],
  create_tx
)

create_sig = rpc.send_transaction(
  Base64.strict_encode64(Txns.wire_encode_transaction(create_signed))
)
puts "Create stake account: #{create_sig}"

Kit::TransactionConfirmation.wait_for_confirmation(
  rpc, create_sig,
  commitment:   :confirmed,
  timeout_secs: 60
)
puts "Stake account confirmed."

# ── 4. Build the second transaction: delegate to a validator ──────────────────
delegate_ix = Stake.delegate_instruction(
  stake_account: stake_keypair.address,
  vote_account:  vote_address,
  authorized:    owner.address    # must sign as the authorised staker
)

bh = rpc.get_latest_blockhash
delegate_constraint = TxMsg::BlockhashLifetimeConstraint.new(
  blockhash:               bh.value.blockhash,
  last_valid_block_height: bh.value.last_valid_block_height
)

delegate_msg = Kit::Functional.pipe(
  TxMsg.create_transaction_message(version: :legacy),
  ->(tx) { TxMsg.set_fee_payer(owner.address, tx) },
  ->(tx) { TxMsg.set_blockhash_lifetime(delegate_constraint, tx) },
  ->(tx) { TxMsg.append_instructions(tx, [delegate_ix]) }
)

delegate_tx     = Txns.compile_transaction_message(delegate_msg)
delegate_signed = Txns.sign_transaction([owner.key_pair.signing_key], delegate_tx)

delegate_sig = rpc.send_transaction(
  Base64.strict_encode64(Txns.wire_encode_transaction(delegate_signed))
)
puts "Delegate stake: #{delegate_sig}"

Kit::TransactionConfirmation.wait_for_confirmation(
  rpc, delegate_sig,
  commitment:   :confirmed,
  timeout_secs: 60
)
puts "Delegation confirmed. Stake account: #{stake_keypair.address}"
```

> **Note** Stake activation takes one full epoch (roughly 2–3 days on mainnet). The account will show status `activating` until then.

## Rails

The gem includes a Railtie that auto-configures when Rails is present. Add it to your `Gemfile` as usual, then run the install generator:

```bash
rails generate solana:ruby:kit:install
```

This creates `config/initializers/ruby_kit.rb`:

```ruby
Solana::Ruby::Kit.configure do |config|
  config.rpc_url    = 'https://api.mainnet-beta.solana.com'
  config.ws_url     = 'wss://api.mainnet-beta.solana.com'
  config.commitment = :confirmed
  config.timeout    = 30
end
```

Or configure via `config/application.rb`:

```ruby
config.ruby_kit.rpc_url    = ENV['SOLANA_RPC_URL']
config.ruby_kit.commitment = :finalized
```

Get a pre-configured client anywhere in your app:

```ruby
rpc = Solana::Ruby::Kit.rpc_client
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `rpc_url` | `https://api.mainnet-beta.solana.com` | JSON-RPC endpoint |
| `ws_url` | `nil` | WebSocket endpoint for subscriptions |
| `commitment` | `:confirmed` | Default commitment level |
| `timeout` | `30` | HTTP read timeout in seconds |

## Modules

### `Solana::Ruby::Kit::Addresses` — `@solana/addresses`

Validate and work with base58-encoded Solana addresses.

```ruby
Addr = Solana::Ruby::Kit::Addresses

# Validate
Addr.address?('11111111111111111111111111111111')  # => true

# Wrap into a typed Address value object (raises on invalid input)
addr = Addr.address('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA')

# Encode / decode raw bytes
bytes = Addr.decode_address(addr)   # => 32-byte binary String
str   = Addr.encode_address(bytes)  # => base58 String

# Program Derived Addresses (PDAs)
program = Addr.address('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA')
pda = Addr.get_program_derived_address(
  program_address: program,
  seeds:           ['my-seed', [1, 2, 3]]
)
puts pda.address  # => Address
puts pda.bump     # => Integer (0-255)
```

### `Solana::Ruby::Kit::Keys` — `@solana/keys`

Ed25519 key generation, signing, and verification via libsodium.

```ruby
Keys = Solana::Ruby::Kit::Keys

# Generate
kp = Keys.generate_key_pair
kp.signing_key  # => RbNaCl::SigningKey
kp.verify_key   # => RbNaCl::VerifyKey

# From 64 raw bytes (seed || public key)
kp = Keys.create_key_pair_from_bytes(File.binread('wallet.bin'))

# From 32-byte private seed only
kp = Keys.create_key_pair_from_private_key_bytes(seed_bytes)

# Sign / verify
sig = Keys.sign_bytes(kp.signing_key, data)
ok  = Keys.verify_signature(kp.verify_key, sig, data)

# Base58-encode a signature
Keys.encode_signature(sig)   # => Signature string
Keys.decode_signature(str)   # => SignatureBytes
```

### `Solana::Ruby::Kit::Signers` — `@solana/signers`

High-level signer abstraction that wraps a key pair and exposes an `address`.

```ruby
Signers = Solana::Ruby::Kit::Signers

# Random new signer
signer = Signers.generate_key_pair_signer
signer.address    # => Addresses::Address
signer.to_s       # => base58 string

# From existing key pair
signer = Signers.create_signer_from_key_pair(kp)

# From raw bytes
signer = Signers.create_key_pair_signer_from_bytes(bytes_64)
signer = Signers.create_key_pair_signer_from_private_key_bytes(seed_32)

# Sign arbitrary data
sig = signer.sign(message_bytes)

# Sign a batch of messages for multiple signers
map = Signers.sign_message_bytes_with_signers([signer1, signer2], bytes)
# => { "addr1" => SignatureBytes, "addr2" => SignatureBytes }
```

### `Solana::Ruby::Kit::TransactionMessages` — `@solana/transaction-messages`

Immutable transaction message builder. Every method returns a new struct; originals are unmodified.

```ruby
TxMsg = Solana::Ruby::Kit::TransactionMessages

msg = TxMsg.create_transaction_message(version: 0)

# Set fee payer
msg = TxMsg.set_fee_payer(signer.address, msg)

# Set blockhash lifetime
constraint = TxMsg::BlockhashLifetimeConstraint.new(
  blockhash: '4vJ9...', last_valid_block_height: 123_456
)
msg = TxMsg.set_blockhash_lifetime(constraint, msg)

# Append / prepend instructions
msg = TxMsg.append_instructions(msg, [instruction])
msg = TxMsg.prepend_instructions(msg, [priority_fee_ix])

# Durable nonce lifetime
nonce_constraint = TxMsg::DurableNonceLifetimeConstraint.new(
  nonce:                 'abc...',
  nonce_account_address: nonce_addr
)
msg = TxMsg.set_durable_nonce_lifetime(nonce_constraint, msg)
```

### `Solana::Ruby::Kit::Transactions` — `@solana/transactions`

Compile, sign, and inspect transactions.

```ruby
Txns = Solana::Ruby::Kit::Transactions

# Compile a TransactionMessage into wire bytes + an empty signatures map.
# message_bytes are the bytes that each required signer must sign.
# A lifetime constraint (blockhash or durable nonce) is optional at compile
# time — omitting it writes 32 zero bytes into the blockhash field, which
# must be replaced before the transaction is valid for submission.
transaction = Txns.compile_transaction_message(message)

# Partially sign (one or more keys, not necessarily all signers)
tx = Txns.partially_sign_transaction([kp.signing_key], transaction)

# Fully sign (raises unless all signers have signed)
signed_tx = Txns.sign_transaction([kp.signing_key], transaction)

# Encode the fully signed transaction for submission via sendTransaction.
# Prepends compact-u16 signature count + 64-byte signatures to message bytes.
wire_bytes  = Txns.wire_encode_transaction(signed_tx)
wire_base64 = Base64.strict_encode64(wire_bytes)

# Get the transaction signature (fee payer's signature, base58)
sig = Txns.get_signature_from_transaction(signed_tx)

# Check completeness and size
Txns.fully_signed_transaction?(tx)      # => true / false
Txns.assert_fully_signed_transaction!(tx)

Txns.within_size_limit?(tx)             # => true if wire size <= 1232 bytes
Txns.assert_within_size_limit!(tx)

# Sendable = fully signed AND within size limit
Txns.sendable_transaction?(signed_tx)   # => true / false
Txns.assert_sendable_transaction!(signed_tx)
```

### `Solana::Ruby::Kit::Rpc` — `@solana/rpc`

Synchronous JSON-RPC client backed by `Net::HTTP`.

```ruby
rpc = Solana::Ruby::Kit::Rpc::Client.new(
  Solana::Ruby::Kit::RpcTypes.devnet,
  timeout:      10,
  open_timeout: 5
)

rpc.get_slot                                  # => Integer
rpc.get_block_height                          # => Integer
rpc.get_balance(address)                      # resp.value => lamports
rpc.get_latest_blockhash                      # resp.value.blockhash, .last_valid_block_height
rpc.get_account_info(address, encoding: 'base64')
rpc.get_multiple_accounts([addr1, addr2])
rpc.get_program_accounts(program_address)
rpc.get_signature_statuses([sig_str])
rpc.is_blockhash_valid(blockhash, commitment: :confirmed)
rpc.get_minimum_balance_for_rent_exemption(data_length)
rpc.get_transaction(signature, encoding: 'base64')
rpc.get_token_account_balance(token_account)
rpc.get_token_accounts_by_owner(owner, mint: mint_address)
rpc.get_epoch_info
rpc.get_vote_accounts
rpc.simulate_transaction(encoded_tx)
rpc.send_transaction(encoded_tx)
rpc.request_airdrop(address, lamports)        # devnet / testnet only
```

Errors:

```ruby
rescue Solana::Ruby::Kit::Rpc::RpcError => e
  puts e.code     # JSON-RPC error code
  puts e.message  # JSON-RPC error message
rescue Solana::Ruby::Kit::Rpc::HttpTransportError => e
  puts e.status   # HTTP status code
```

### `Solana::Ruby::Kit::RpcTypes` — `@solana/rpc-types`

Cluster URL helpers and typed wrappers.

```ruby
RpcTypes = Solana::Ruby::Kit::RpcTypes

RpcTypes.mainnet                             # default mainnet URL
RpcTypes.mainnet('https://my-rpc.com')       # custom mainnet URL
RpcTypes.devnet                              # devnet
RpcTypes.testnet                             # testnet
RpcTypes.cluster_url('http://localhost:8899') # custom / localnet
```

### `Solana::Ruby::Kit::Options` — `@solana/options`

Rust-style `Option<T>` for Solana's on-chain option codec pattern.

```ruby
Opts = Solana::Ruby::Kit::Options

some = Opts.some(42)          # => Some(42)
none = Opts.none              # => None

Opts.some?(some)              # => true
Opts.none?(none)              # => true
Opts.option?(some)            # => true

Opts.unwrap_option(some)      # => 42
Opts.unwrap_option(none)      # => nil
Opts.unwrap_option(none, -> { 0 })  # => 0

Opts.wrap_nullable(nil)       # => None
Opts.wrap_nullable(42)        # => Some(42)

# Recursively unwrap nested structures
Opts.unwrap_option_recursively({ a: some, b: [none, some] })
# => { a: 42, b: [nil, 42] }
```

### `Solana::Ruby::Kit::Functional` — `@solana/functional`

Functional pipeline composition.

```ruby
Kit = Solana::Ruby::Kit

result = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: 0),
  ->(tx) { Kit::TransactionMessages.set_fee_payer(fee_payer, tx) },
  ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(constraint, tx) },
  ->(tx) { Kit::TransactionMessages.append_instructions(tx, [ix]) }
)
```

### `Solana::Ruby::Kit::Codecs` — `@solana/codecs`

Binary encoder/decoder framework for Solana on-chain data.

```ruby
Codecs = Solana::Ruby::Kit::Codecs

# Numbers
u8  = Codecs.u8
u16 = Codecs.u16_le   # little-endian (default for Solana)
u32 = Codecs.u32_le
u64 = Codecs.u64_le
i8  = Codecs.i8
f32 = Codecs.f32_le

u16.encode(1000)       # => "\xe8\x03"
u16.decode("\xe8\x03") # => 1000

# Strings
utf8  = Codecs.utf8
bytes = Codecs.bytes_codec

# Data structures
struct_codec = Codecs.struct_codec([
  ['amount', u64],
  ['mint',   bytes]
])
```

### `Solana::Ruby::Kit::RpcSubscriptions` — `@solana/rpc-subscriptions`

WebSocket-based subscription client.

```ruby
ws = Solana::Ruby::Kit::RpcSubscriptions::Client.new(
  'wss://api.devnet.solana.com'
)

sub = ws.account_subscribe(address, commitment: :confirmed)
sub.on_message { |notification| puts notification }
sub.on_error   { |err|          puts err }

ws.account_unsubscribe(sub.id)
ws.close
```

### `Solana::Ruby::Kit::Sysvars` — `@solana/sysvars`

Well-known sysvar addresses and decoded account data.

```ruby
Sysvars = Solana::Ruby::Kit::Sysvars

Sysvars::Addresses::CLOCK_ADDRESS          # => Address
Sysvars::Addresses::RENT_ADDRESS
Sysvars::Addresses::EPOCH_SCHEDULE_ADDRESS

# Fetch and decode via an RPC client
clock = Sysvars.fetch_clock(rpc)
clock.slot              # => Integer
clock.epoch             # => Integer
clock.unix_timestamp    # => Integer

rent = Sysvars.fetch_rent(rpc)
rent.lamports_per_byte_year  # => Integer
rent.exemption_threshold     # => Float
```

### `Solana::Ruby::Kit::Programs` — `@solana/programs`

Program error helpers and well-known program interfaces.

```ruby
Programs = Solana::Ruby::Kit::Programs

# Inspect custom program errors in transaction simulation results
Programs.program_error?(err)                   # => true / false
Programs.program_error?(err, expected_code: 1) # match a specific code
Programs.get_program_error_code(err)           # => Integer or nil
```

#### `Programs::StakeProgram`

Create and delegate stake accounts.

```ruby
Stake = Solana::Ruby::Kit::Programs::StakeProgram

# Well-known addresses
Stake::PROGRAM_ID       # Stake11111111111111111111111111111111111111
Stake::STAKE_CONFIG_ID  # StakeConfig11111111111111111111111111111111
Stake::STAKE_ACCOUNT_SPACE  # => 200 (bytes required for a stake account)

# Build two instructions that allocate and initialise a new stake account.
# The caller appends both to a transaction message.
create_ixs = Stake.create_account_instructions(
  from:          fee_payer_address,   # funding wallet (writable, signer)
  stake_account: stake_keypair.address, # new stake account address (writable, signer)
  authorized:    owner_address,       # becomes both staker and withdrawer
  lamports:      2_282_880            # enough for rent + some stake
)

# Build one instruction that delegates an initialised stake account.
delegate_ix = Stake.delegate_instruction(
  stake_account: stake_keypair.address,
  vote_account:  validator_vote_address,
  authorized:    owner_address         # must sign the transaction
)
```

#### `Programs::AssociatedTokenAccount`

Create SPL token accounts at their canonical (Associated Token Account) address.

```ruby
ATA = Solana::Ruby::Kit::Programs::AssociatedTokenAccount

# Well-known program IDs
ATA::PROGRAM_ID          # ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL
ATA::TOKEN_PROGRAM_ID    # TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
ATA::TOKEN_2022_PROGRAM_ID
ATA::SYSTEM_PROGRAM_ID

# Derive the ATA address (no RPC call required)
pda = ATA.get_associated_token_address(
  wallet:           owner_address,
  mint:             mint_address,
  token_program_id: ATA::TOKEN_PROGRAM_ID   # default; omit for SPL Token
)
pda.address  # => Addresses::Address (the ATA)
pda.bump     # => Integer

# Build the createAssociatedTokenAccount instruction
ix = ATA.create_instruction(
  payer:            fee_payer_address,  # pays rent
  wallet:           owner_address,      # will own the ATA
  mint:             mint_address,
  token_program_id: ATA::TOKEN_PROGRAM_ID,
  idempotent:       true   # use CreateIdempotent — safe to call if ATA exists
)
```

### `Solana::Ruby::Kit::OffchainMessages` — `@solana/signers`

Sign and verify off-chain messages (Phantom wallet standard).

```ruby
OffChain = Solana::Ruby::Kit::OffchainMessages

msg = OffChain.create_message('Hello, Solana!')
encoded = OffChain.encode_message(msg)

sig     = signer.sign(encoded)
decoded = OffChain.decode_message(encoded)
```

### `Solana::Ruby::Kit::TransactionConfirmation` — `@solana/transaction-confirmation`

Poll for transaction confirmation with timeout.

```ruby
Confirm = Solana::Ruby::Kit::TransactionConfirmation

Confirm.confirm_transaction(
  rpc:        rpc,
  signature:  sig,
  commitment: :confirmed,
  timeout:    60
)
```

### `Solana::Ruby::Kit::InstructionPlans` — `@solana/instruction-plans`

Plan and execute instruction sequences that may span multiple transactions.
The planner packs instructions into messages respecting the 1232-byte transaction
size limit; the executor walks the resulting plan tree and sends each transaction.

```ruby
require 'base64'
Plans = Solana::Ruby::Kit::InstructionPlans
Kit   = Solana::Ruby::Kit

# ── 1. Build an instruction plan ─────────────────────────────────────────────
# Instructions are auto-wrapped in SingleInstructionPlan.
# Use parallel_instruction_plan for instructions that can run concurrently.
plan = Plans.sequential_instruction_plan([ix1, ix2, ix3])

# ── 2. Create a planner ───────────────────────────────────────────────────────
# create_transaction_message is called whenever a new (empty) transaction is
# needed. It must return a message with a fee payer and blockhash already set.
planner = Plans.create_transaction_planner(
  create_transaction_message: -> {
    Kit::Functional.pipe(
      Kit::TransactionMessages.create_transaction_message(version: :legacy),
      ->(tx) { Kit::TransactionMessages.set_fee_payer(signer.address, tx) },
      ->(tx) { Kit::TransactionMessages.set_blockhash_lifetime(constraint, tx) }
    )
  }
)

# plan! distributes instructions across as few transactions as possible.
transaction_plan = planner.call(plan)

# ── 3. Create an executor and run it ─────────────────────────────────────────
# execute_transaction_message receives each fully-packed TransactionMessage and
# must return { transaction: <signed Transaction>, context: <optional Hash> }.
# If it raises, the executor cancels all remaining messages and re-raises.
executor = Plans.create_transaction_plan_executor(
  execute_transaction_message: ->(message) {
    transaction = Kit::Transactions.compile_transaction_message(message)
    signed      = Kit::Transactions.sign_transaction([signer.key_pair.signing_key], transaction)
    wire        = Base64.strict_encode64(Kit::Transactions.wire_encode_transaction(signed))
    rpc.send_transaction(wire)
    { transaction: signed }
  }
)

result = executor.call(transaction_plan)
# result is a TransactionPlanResult tree mirroring the transaction_plan structure.
# Each leaf is a SingleTransactionPlanResult with status :successful, :failed, or :canceled.

# ── 4. Plan types ─────────────────────────────────────────────────────────────
Plans.single_instruction_plan(ix)                      # wrap one instruction
Plans.sequential_instruction_plan([ix1, ix2])          # ordered, divisible
Plans.non_divisible_sequential_instruction_plan([ix1, ix2])  # must be atomic
Plans.parallel_instruction_plan([ix1, ix2])            # any order / same tx

# MessagePacker plans for instructions of variable size (e.g. large data writes)
Plans.get_linear_message_packer_instruction_plan(
  total_length:    data.bytesize,
  get_instruction: ->(offset, length) { build_write_ix(offset, data[offset, length]) }
)
```

### `Solana::Ruby::Kit::WalletStandard` — `@solana/wallet-standard`

Server-side handling of the [Wallet Standard](https://github.com/wallet-standard/wallet-standard)
`signTransaction` interface. A browser wallet (Phantom, Backpack, Solflare, …) signs a
transaction and returns wire bytes; Rails decodes those bytes and verifies every Ed25519
signature without broadcasting — because Solana addresses **are** Ed25519 public keys, no
additional key lookup is required.

#### Verify a wallet-signed transaction in a Rails controller

```ruby
# app/controllers/payments_controller.rb
require 'base64'

WS = Solana::Ruby::Kit::WalletStandard
TX = Solana::Ruby::Kit::Transactions

class PaymentsController < ApplicationController
  # POST /payments/verify
  # Body: { signed_transaction: "<base64 wire bytes from wallet>" }
  def verify
    wire_bytes = Base64.strict_decode64(params[:signed_transaction])

    # 1. Decode the wallet output and verify every present signature.
    #    Raises WalletStandard::SIGNATURE_VERIFICATION_FAILED on any mismatch.
    tx = WS.verify_signed_transaction!(wire_bytes)

    # 2. Assert all required signers have signed (no nil slots remain).
    TX.assert_fully_signed_transaction!(tx)

    # 3. Confirm the expected wallet address actually signed.
    wallet_address = Solana::Ruby::Kit::Addresses::Address.new(params[:wallet_address])
    render json: { error: 'wrong signer' }, status: :unprocessable_entity and return \
      unless WS.signed_by?(tx, wallet_address)

    # 4. Optionally broadcast through your own RPC node instead of the browser.
    rpc      = Solana::Ruby::Kit.rpc_client
    wire_b64 = Base64.strict_encode64(TX.wire_encode_transaction(tx))
    sig      = rpc.send_transaction(wire_b64, encoding: 'base64')

    render json: { signature: sig.value }
  rescue Solana::Ruby::Kit::SolanaError => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  end
end
```

#### Build the transaction server-side, send to the browser for signing, then verify

```ruby
Kit = Solana::Ruby::Kit
WS  = Kit::WalletStandard

# ── Server: build and serialise the unsigned transaction ─────────────────────
fee_payer   = Kit::Addresses::Address.new(params[:wallet_address])
rpc         = Kit.rpc_client
latest      = rpc.get_latest_blockhash
constraint  = Kit::TransactionMessages::BlockhashLifetimeConstraint.new(
  blockhash:               latest['blockhash'],
  last_valid_block_height: latest['lastValidBlockHeight']
)

message = Kit::Functional.pipe(
  Kit::TransactionMessages.create_transaction_message(version: :legacy),
  ->(m) { Kit::TransactionMessages.set_fee_payer(fee_payer, m) },
  ->(m) { Kit::TransactionMessages.set_blockhash_lifetime(constraint, m) }
)

compiled        = Kit::Transactions.compile_transaction_message(message)
unsigned_wire   = Kit::Transactions.wire_encode_transaction(compiled)
unsigned_base64 = Base64.strict_encode64(unsigned_wire)

# → send unsigned_base64 to the browser
# → browser calls: wallet.features['solana:signTransaction'].signTransaction(tx)
# → browser POSTs { signed_transaction: "<base64>" } back to /payments/verify

# ── Server: receive and verify the signed transaction ────────────────────────
tx = WS.verify_signed_transaction!(Base64.strict_decode64(params[:signed_transaction]))
Kit::Transactions.assert_fully_signed_transaction!(tx)
```

#### Wallet Standard feature constants

Use these when building frontend metadata or documenting required wallet capabilities:

```ruby
WS = Solana::Ruby::Kit::WalletStandard

WS::SIGN_TRANSACTION          # => 'solana:signTransaction'
WS::SIGN_AND_SEND_TRANSACTION # => 'solana:signAndSendTransaction'
WS::SIGN_MESSAGE              # => 'solana:signMessage'
WS::CONNECT                   # => 'standard:connect'
```

## Error handling

All errors inherit from `Solana::Ruby::Kit::SolanaError`.

```ruby
rescue Solana::Ruby::Kit::SolanaError => e
  puts e.code     # => :SOLANA_ERROR__ADDRESSES__INVALID_BASE58_ENCODED_ADDRESS
  puts e.message  # => human-readable description
  puts e.context  # => Hash of structured context values
end
```

Error codes match the TypeScript `@solana/errors` package constants.

## Type checking with Sorbet

Every public method has a `sig` block. To enable static type checking in your project:

```bash
bundle exec srb init
bundle exec srb tc
```

## Development

```bash
bundle install
bundle exec rspec            # run tests
bundle exec srb tc           # type-check
bundle exec tapioca gems     # regenerate gem RBI files (first time or after gem updates)
```

## License

MIT
