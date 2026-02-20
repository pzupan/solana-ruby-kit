# typed: strict
# frozen_string_literal: true

require_relative '../addresses/address'

module Solana::Ruby::Kit
  module RpcTypes
    # Base fields present in every account-info response.
    # Mirrors TypeScript's `AccountInfoBase`.
    class AccountInfoBase < T::Struct
      const :executable, T::Boolean
      # Balance in lamports.
      const :lamports,   Integer
      # Address of the program that owns this account.
      const :owner,      String        # base58 address string
      # Allocated storage in bytes (excludes the 128-byte header).
      # TypeScript uses bigint; Ruby uses Integer.
      const :space,      Integer
    end

    # Account info with raw base64-encoded data (the most common encoding).
    # Mirrors `AccountInfoWithBase64EncodedData`.
    class AccountInfoWithBase64Data < T::Struct
      const :executable,  T::Boolean
      const :lamports,    Integer
      const :owner,       String
      const :space,       Integer
      const :rent_epoch,  Integer, default: 0
      # Tuple: [base64_string, "base64"]
      const :data,        T::Array[String]
    end

    # Account info with JSON-parsed data (program-specific parsing on the RPC node).
    # Mirrors `AccountInfoWithJsonData`.
    class AccountInfoWithJsonData < T::Struct
      const :executable,  T::Boolean
      const :lamports,    Integer
      const :owner,       String
      const :space,       Integer
      const :rent_epoch,  Integer, default: 0
      # Either a hash (parsed JSON) or a base64 fallback tuple.
      const :data,        T.untyped
    end

    # Slot + context wrapper returned by context-aware RPC methods.
    # Mirrors TypeScript's `SolanaRpcResponse<T>`:
    #   { context: { slot: bigint }, value: T }
    class RpcContextualValue < T::Struct
      const :slot,  Integer   # the slot at which the data was read
      const :value, T.untyped # the actual result (typed by the caller)
    end
  end
end
