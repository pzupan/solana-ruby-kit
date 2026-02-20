module T
  module Helpers
    prepend(::Module.new do
      def requires_ancestor(&block)
        # We can't directly call the block since the ancestor might not be loaded yet.
        # We save the block in the map and will resolve it later.
        Tapioca::Runtime::Trackers::RequiredAncestor.register(self, block)

        super
      end
    end)
  end
end
