require 'active_support/dependencies'
module ActiveSupport #:nodoc:
  module Dependencies #:nodoc:
    module Helpers #:nodoc:

      def hooked?
        Module.method(:const_missing).owner.parent == ActiveSupport::Dependencies
      end

      def unhooked?
        !hooked?
      end

      def with_hook(&block)
        start_hooked = hooked?
        Dependencies.hook! unless start_hooked
        block.yield
      ensure
        Dependencies.unhook! unless start_hooked
      end
      alias_method :with_autoloading, :with_hook

      def without_hook(&block)
        start_hooked = hooked?
        Dependencies.unhook! if start_hooked
        block.yield
      ensure
        Dependencies.hook! if start_hooked
      end
      alias_method :without_autoloading, :without_hook

      def loaded?(obj_name)
        obj = without_hook do
          obj_name.to_s.camelize.safe_constantize
        end
        obj.nil?
      end
    end
  end
end

ActiveSupport::Dependencies.extend ActiveSupport::Dependencies::Helpers
