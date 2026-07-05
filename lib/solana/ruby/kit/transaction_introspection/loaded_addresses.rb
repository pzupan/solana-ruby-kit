# typed: strict
# frozen_string_literal: true

require_relative '../addresses/address'

module Solana::Ruby::Kit
  module TransactionIntrospection
    # Loaded ALT addresses as returned by `getTransaction`'s `meta.loadedAddresses`.
    # The two arrays are kept in the same order the runtime uses to resolve
    # instruction account indices.
    # Mirrors `LoadedAddresses` from @solana/transaction-introspection.
    class LoadedAddresses < T::Struct
      const :readonly, T::Array[Addresses::Address]
      const :writable, T::Array[Addresses::Address]
    end

    EMPTY_LOADED_ADDRESSES = T.let(LoadedAddresses.new(readonly: [], writable: []), LoadedAddresses)
  end
end
