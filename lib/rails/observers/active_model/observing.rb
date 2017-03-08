require 'rails/observers/active_model'

module ActiveModel
  # == Active Model Observers Activation
  module Observing
    extend ActiveSupport::Concern

    included do
      extend ::ActiveSupport::DescendantsTracker
      def self.inherited(subclass)
        super
        subclass.observer_orm.instantiate_observers.each do |observer_inst|
          observer_inst.try_hook!(subclass)
        end
      end
    end

    module ClassMethods
      # Activates the observers assigned.
      #
      #   class ORM
      #     include ActiveModel::Observing
      #   end
      #
      #   # Calls PersonObserver.instance
      #   ORM.observers = :person_observer
      #
      #   # Calls Cacher.instance and GarbageCollector.instance
      #   ORM.observers = :cacher, :garbage_collector
      #
      #   # Same as above, just using explicit class references
      #   ORM.observers = Cacher, GarbageCollector
      #
      # Note: Setting this does not instantiate the observers yet.
      # <tt>instantiate_observers</tt> is called during startup, and before
      # each development request.
      def observers=(*values)
        observers.replace(values.flatten)
      end

      # Gets an array of observers observing this model. The array also provides
      # +enable+ and +disable+ methods that allow you to selectively enable and
      # disable observers (see ActiveModel::ObserverArray.enable and
      # ActiveModel::ObserverArray.disable for more on this).
      #
      #   class ORM
      #     include ActiveModel::Observing
      #   end
      #
      #   ORM.observers = :cacher, :garbage_collector
      #   ORM.observers       # => [:cacher, :garbage_collector]
      #   ORM.observers.class # => ActiveModel::ObserverArray
      def observers
        @observers ||= ObserverArray.new(self)
      end

      # Returns the current observer instances.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #   Foo.instantiate_observers
      #
      #   Foo.observer_instances # => [#<FooObserver:0x007fc212c40820>]
      def observer_instances
        @observer_instances ||= Set.new
      end

      # Instantiate the global observers.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #
      #   foo = Foo.new
      #   foo.status = false
      #   foo.notify_observers(:on_spec)
      #   foo.status # => false
      #
      #   obs = Foo.instantiate_observers # => [#<FooObserver:0x007fc212c40820>]
      #   obs.each { |o| o.try_hook!(Foo) }
      #
      #   foo = Foo.new
      #   foo.status = false
      #   foo.notify_observers(:on_spec)
      #   foo.status # => true
      def instantiate_observers
        observers.map { |o| instantiate_observer(o) }
      end

      # Add a new observer to the pool. The new observer needs to respond to
      # <tt>update</tt>, otherwise it raises an +ArgumentError+ exception.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #   end
      #
      #   Foo.add_observer(FooObserver.instance)
      #
      #   Foo.observer_instances
      #   # => [#<FooObserver:0x007fccf55d9390>]
      def add_observer(observer)
        unless observer.respond_to? :update
          raise ArgumentError, "observer needs to respond to 'update'"
        end
        observer_instances << observer
      end

      # Fires notifications to model's observers.
      #
      #   def save
      #     notify_observers(:before_save)
      #     ...
      #     notify_observers(:after_save)
      #   end
      #
      # Custom notifications can be sent in a similar fashion:
      #
      #   notify_observers(:custom_notification, :foo)
      #
      # This will call <tt>custom_notification</tt>, passing as arguments
      # the current object and <tt>:foo</tt>.
      def notify_observers(*args)
        observer_instances.each { |observer| observer.update(*args) }
      end

      # Returns the total number of instantiated observers.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #   Foo.observers_count # => 0
      #   Foo.instantiate_observers
      #   Foo.observers_count # => 1
      def observers_count
        observer_instances.size
      end

      # <tt>count_observers</tt> is deprecated. Use #observers_count.
      def count_observers
        msg = "count_observers is deprecated in favor of observers_count"
        ActiveSupport::Deprecation.warn(msg)
        observers_count
      end

      # Inheritable, read-only, lazily-determined, memoized class variable reader
      # referring to the Active.*::Base class that included ::ActiveModel::Observing
      def observer_orm #:nodoc:#
        @@observer_orm ||= begin
          self_and_parents = self.ancestors.unshift(self)
          self_and_parents.reverse.detect do |klass|
            klass.included_modules.include?(::ActiveModel::Observing)
          end
        end
      end

    protected
      def instantiate_observer(observer) #:nodoc:
        # string/symbol
        if observer.respond_to?(:to_sym)
          observer = observer.to_s.camelize.constantize
        end
        if observer.respond_to?(:instance)
          observer.instance
        else
          raise ArgumentError,
            "#{observer} must be a lowercase, underscored class name (or " +
            "the class itself) responding to the method :instance. " +
            "Example: Person.observers = :big_brother # calls " +
            "BigBrother.instance"
        end
      end

      # Notify observers when the observed class is subclassed.
      def inherited(subclass) #:nodoc:
        super
        notify_observers :observed_class_inherited, subclass
      end

    end

    # Notify a change to the list of observers.
    #
    #   class Foo
    #     include ActiveModel::Observing
    #
    #     attr_accessor :status
    #   end
    #
    #   class FooObserver < ActiveModel::Observer
    #     def on_spec(record, *args)
    #       record.status = true
    #     end
    #   end
    #
    #   Foo.observers = FooObserver
    #   Foo.instantiate_observers # => [FooObserver]
    #
    #   foo = Foo.new
    #   foo.status = false
    #   foo.notify_observers(:on_spec)
    #   foo.status # => true
    #
    # See ActiveModel::Observing::ClassMethods.notify_observers for more
    # information.
    def notify_observers(method, *extra_args)
      self.class.notify_observers(method, self, *extra_args)
    end
  end
end
