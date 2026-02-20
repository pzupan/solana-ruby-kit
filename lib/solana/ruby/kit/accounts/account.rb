# typed: strict
# frozen_string_literal: true

require_relative '../addresses/address'
require_relative '../errors'

module Solana::Ruby::Kit
  module Accounts
    # The number of bytes required to store the on-chain account header
    # (lamports, owner, executable flag, rent epoch, and padding).
    # Mirrors TypeScript's `BASE_ACCOUNT_SIZE = 128`.
    BASE_ACCOUNT_SIZE = T.let(128, Integer)

    # All on-chain attributes shared by every Solana account.
    # Mirrors TypeScript's `BaseAccount`.
    class BaseAccount < T::Struct
      # Whether the account holds a program (executable code).
      const :executable,      T::Boolean
      # Balance of the account in lamports (1 SOL = 1_000_000_000 lamports).
      # TypeScript uses `bigint`; Ruby uses arbitrary-precision Integer.
      const :lamports,        Integer
      # Address of the program that owns this account.
      const :program_address, Addresses::Address
      # Allocated storage in bytes.
      const :space,           Integer
    end

    # A fully-populated Solana account including its address and data.
    # Mirrors TypeScript's `Account<TData, TAddress>`.
    #
    # `data` is either:
    #   - a binary String (when the account is encoded / raw bytes), or
    #   - any Ruby object (when the account has been decoded by a codec).
    class Account < T::Struct
      const :address,         Addresses::Address
      const :data,            T.untyped  # String (binary) or decoded struct
      const :executable,      T::Boolean
      const :lamports,        Integer
      const :program_address, Addresses::Address
      const :space,           Integer
    end

    # Convenience alias for an account whose data is still raw bytes.
    # Mirrors TypeScript's `EncodedAccount<TAddress>`.
    EncodedAccount = T.type_alias { Account }
  end
end
