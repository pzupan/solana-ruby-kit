# typed: strict
# frozen_string_literal: true

require_relative 'has_transport'

module Solana::Ruby::Kit
  module Rpc
    module Api
      # The block an Alpenglow genesis certificate certifies.
      AgGenesisCertBlock = T.let(
        Struct.new(
          :block_id, # Array<Integer> — block id of the certified block, as a 32-byte array
          :slot,     # Integer — slot of the certified block
          keyword_init: true
        ),
        T.untyped
      )

      # The aggregate signature over an Alpenglow genesis certificate.
      AgGenesisCertSignature = T.let(
        Struct.new(
          :bitmap,    # Array<Integer> — ranks of the validators in the aggregate signature
          :signature, # Array<Integer> — the 192-byte aggregate BLS signature
          keyword_init: true
        ),
        T.untyped
      )

      # The Alpenglow genesis certificate, as gossiped between validators.
      # Mirrors the `WireBlockCertMessage` type in the Agave validator.
      AgGenesisCert = T.let(
        Struct.new(
          :block,     # AgGenesisCertBlock
          :signature, # AgGenesisCertSignature
          keyword_init: true
        ),
        T.untyped
      )

      # Returns the Alpenglow genesis certificate — the certificate over the block at which the
      # Alpenglow consensus protocol was activated — or nil if the node does not have one.
      # Mirrors TypeScript's GetAgGenesisCertApi.getAgGenesisCert.
      # @see https://solana.com/docs/rpc/http/getaggenesiscert
      module GetAgGenesisCert
        extend T::Sig
        extend T::Helpers

        requires_ancestor { HasTransport }

        sig { returns(T.untyped) }
        def get_ag_genesis_cert
          raw = transport.request('getAgGenesisCert', [])
          return nil if raw.nil?

          block     = raw['block'] || {}
          signature = raw['signature'] || {}

          AgGenesisCert.new(
            block:     AgGenesisCertBlock.new(
              block_id: Kernel.Array(block['blockId']).map { |b| Kernel.Integer(b) },
              slot:     Kernel.Integer(block['slot'])
            ),
            signature: AgGenesisCertSignature.new(
              bitmap:    Kernel.Array(signature['bitmap']).map { |b| Kernel.Integer(b) },
              signature: Kernel.Array(signature['signature']).map { |b| Kernel.Integer(b) }
            )
          )
        end
      end
    end
  end
end
