# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module RpcSubscriptions
    module Api
      # Interface supplying the WebSocket connection and subscription plumbing
      # that every notification mixin uses.
      #
      # The mixins in this namespace are not usable on their own — each one
      # opens its subscription through `transport` and wraps it with
      # `_build_subscription`, both provided by the object they are mixed into
      # (`RpcSubscriptions::Client`).  Declaring that requirement here, and
      # having each mixin `requires_ancestor { HasTransport }`, lets Sorbet
      # resolve those calls inside the mixins instead of reporting them missing.
      module HasTransport
        extend T::Sig
        extend T::Helpers
        abstract!

        # The WebSocket connection used to issue JSON-RPC subscription requests.
        sig { abstract.returns(Transport) }
        def transport; end

        private

        # Wrap a server-assigned subscription id in a `Subscription` that
        # unsubscribes via `unsub_method` when closed.  Private, matching the
        # visibility it has on `RpcSubscriptions::Client`.
        sig { abstract.params(sub_id: T.untyped, unsub_method: String).returns(Subscription) }
        def _build_subscription(sub_id, unsub_method); end
      end
    end
  end
end
