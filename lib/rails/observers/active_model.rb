require 'set'
require 'singleton'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/deprecation'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/try'
require 'active_support/descendants_tracker'

module ActiveModel
  autoload :Observer, 'rails/observers/active_model/observer'
  autoload :ObserverArray, 'rails/observers/active_model/observer_array'
  autoload :Observing, 'rails/observers/active_model/observing'
end
