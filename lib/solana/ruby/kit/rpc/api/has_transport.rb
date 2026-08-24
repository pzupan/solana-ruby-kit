# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Interface supplying the JSON-RPC connection that every API mixin uses.
      #
      # The mixins in this namespace are not usable on their own — each one
      # issues its request through `transport`, which is provided by the object
      # they are mixed into (`Rpc::Client`).  Declaring that requirement here,
      # and having each mixin `requires_ancestor { HasTransport }`, lets Sorbet
      # resolve `transport` inside the mixins instead of reporting it missing.
      module HasTransport
        extend T::Sig
        extend T::Helpers
        interface!

        # The HTTP connection used to issue JSON-RPC requests.
        sig { abstract.returns(Transport) }
        def transport; end
      end
    end
  end
end
