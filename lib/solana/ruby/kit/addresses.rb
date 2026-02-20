# typed: strict
# frozen_string_literal: true

# Utilities for generating and validating Solana account addresses.
# Mirrors the TypeScript package @solana/addresses.
#
# Can be used standalone or as part of Solana::Ruby::Kit.
require_relative 'addresses/address'
require_relative 'addresses/curve'
require_relative 'addresses/program_derived_address'
require_relative 'addresses/public_key'
