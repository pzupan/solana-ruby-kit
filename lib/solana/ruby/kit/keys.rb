# typed: strict
# frozen_string_literal: true

# Utilities for validating, generating, and manipulating Ed25519 key material
# and signatures. Mirrors the TypeScript package @solana/keys.
#
# Can be used standalone or as part of Solana::Ruby::Kit.
require_relative 'keys/private_key'
require_relative 'keys/public_key'
require_relative 'keys/signatures'
require_relative 'keys/key_pair'
