`# Project Name

Ruby-Kit is a translation of the Anza-xyz/kit into Ruby.



## Tech Stack

- Ruby
- Sorbet (gem) for static type checking
- RbNaCl (gem) for Ed25519 cryptographic operations (libsodium bindings)
- RSpec for testing
- Rake as the build tool



## Rules

- Use functional components and hooks — in Ruby this means `module_function` methods within modules, not instance-method classes.

- Use static types in Ruby using the Sorbet gem. Every public method must have a `sig` block. Mark files `# typed: strict`.

- Value objects (Address, Signature, etc.) are lightweight wrapper classes, not plain strings, to give type-level distinction analogous to TypeScript branded types.


## Translated Packages

| Ruby module | TypeScript package |
|---|---|
| `RubyKit::Encoding::Base58` | (shared utility) |
| `RubyKit::Functional` | `@solana/functional` |
| `RubyKit::Options` | `@solana/options` |
| `RubyKit::Addresses` | `@solana/addresses` |
| `RubyKit::Keys` | `@solana/keys` |
| `RubyKit::Accounts` | `@solana/accounts` |
| `RubyKit::Instructions` | `@solana/instructions` |
| `RubyKit::TransactionMessages` | `@solana/transaction-messages` |
| `RubyKit::Transactions` | `@solana/transactions` |
| `RubyKit::Signers` | `@solana/signers` |
| `RubyKit::RpcTypes` | `@solana/rpc-types` |
| `RubyKit::Rpc` | `@solana/rpc` + `@solana/rpc-transport-http` |

Not translated (browser/platform polyfills, React, GraphQL, WebSocket, build tools):
`react`, `webcrypto-ed25519-polyfill`, `ws-impl`, `event-target-impl`, `fetch-impl`,
`text-encoding-impl`, `rpc-graphql`, `rpc-subscriptions-channel-websocket`,
`build-scripts`, `tsconfig`, `eslint-config`, `test-config`.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Type-check with Sorbet
bundle exec srb tc

# Set up Sorbet (first time only)
bundle exec tapioca init
bundle exec tapioca gems   # generate RBI files for gems

# Run specific test file
bundle exec rspec spec/ruby_kit/addresses/address_spec.rb
```


## Gotchas

- **No async/await**: TypeScript's Web Crypto API is async. Ruby's RbNaCl is synchronous. All methods that were `async` in TypeScript are plain synchronous methods here.

- **CryptoKey → RbNaCl types**: TypeScript's opaque `CryptoKey` maps to `RbNaCl::SigningKey` (private) and `RbNaCl::VerifyKey` (public). These are passed as `T.untyped` in Sorbet because RBI files for `rbnacl` require `tapioca gems` to generate.

- **Uint8Array → binary String**: JavaScript `Uint8Array` maps to a Ruby `String` with `Encoding::ASCII_8BIT` (binary). Always call `.b` when forcing binary encoding.

- **Base58**: No external gem is used for base58. The implementation lives in `RubyKit::Encoding::Base58` and uses the Bitcoin/Solana alphabet.

- **Ed25519 curve check**: The `on_ed25519_curve?` implementation in `RubyKit::Addresses::Curve` is pure Ruby math following RFC 8032 Section 5.1.3. It is used for PDA derivation to reject addresses that lie on the curve.

- **T::Struct**: `ProgramDerivedAddress` and `KeyPair` use `T::Struct`. `sorbet-runtime` must be loaded before any of these classes are defined — this happens via `require 'ruby_kit'`.

- **Sorbet RBI files**: After running `bundle install`, run `bundle exec tapioca gems` to generate RBI files so Sorbet can type-check calls into `rbnacl`.

- **RPC transport**: `RubyKit::Rpc::Transport` uses `Net::HTTP` (stdlib) for synchronous JSON-RPC POST requests. TypeScript's `async fetch` maps to blocking Ruby I/O. Use threads or Ractors for concurrency.

- **RPC errors**: JSON-RPC error payloads raise `RubyKit::Rpc::RpcError`; HTTP non-2xx responses raise `RubyKit::Rpc::HttpTransportError`.

- **RPC tests**: `spec/ruby_kit/rpc/client_spec.rb` uses the `webmock` gem to stub `Net::HTTP` calls — add `gem 'webmock'` to the `:development, :test` group and run `bundle install`.
