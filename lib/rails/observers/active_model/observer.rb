require 'rails/observers/active_model'

module ActiveModel
  # == Active Model Observers
  #
  # Observer classes respond to life cycle callbacks to implement trigger-like
  # behavior outside the original class. This is a great way to reduce the
  # clutter that normally comes when the model class is burdened with
  # functionality that doesn't pertain to the core responsibility of the
  # class.
  #
  #   class CommentObserver < ActiveModel::Observer
  #     def after_save(comment)
  #       Notifications.comment('admin@do.com', 'New comment was posted', comment).deliver
  #     end
  #   end
  #
  # This Observer sends an email when a <tt>Comment#save</tt> is finished.
  #
  #   class ContactObserver < ActiveModel::Observer
  #     def after_create(contact)
  #       contact.logger.info('New contact added!')
  #     end
  #
  #     def after_destroy(contact)
  #       contact.logger.warn("Contact with an id of #{contact.id} was destroyed!")
  #     end
  #   end
  #
  # This Observer uses logger to log when specific callbacks are triggered.
  #
  # == Observing a class that can't be inferred
  #
  # Observers will by default be mapped to the class with which they share a
  # name. So <tt>CommentObserver</tt> will be tied to observing <tt>Comment</tt>,
  # <tt>ProductManagerObserver</tt> to <tt>ProductManager</tt>, and so on. If
  # you want to name your observer differently than the class you're interested
  # in observing, you can use the <tt>Observer.observe</tt> class method which
  # takes a symbol for that class (<tt>:product</tt>):
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account
  #
  #     def after_update(account)
  #       AuditTrail.new(account, 'UPDATED')
  #     end
  #   end
  #
  # If the audit observer needs to watch more than one kind of object, this can
  # be specified with multiple arguments:
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account, :balance
  #
  #     def after_update(record)
  #       AuditTrail.new(record, 'UPDATED')
  #     end
  #   end
  #
  # The <tt>AuditObserver</tt> will now act on both updates to <tt>Account</tt>
  # and <tt>Balance</tt> by treating them both as records.
  #
  # If you're using an Observer in a Rails application with Active Record, be
  # sure to read about the necessary configuration in the documentation for
  # ActiveRecord::Observer.
  class Observer
    include Singleton
    extend ActiveSupport::DescendantsTracker

    class << self
      # Attaches the observer to the supplied model classes.
      #
      #   class AuditObserver < ActiveModel::Observer
      #     observe :account, :balance
      #   end
      #
      #   AuditObserver.observed_class_names # => [:account, :balance]
      def observe(*models)
        raise ArgumentError, "#{self}.observe must be passed class names and not constants, to prevent circular dependencies or reloading issues between the model and observer" if models.any? { |m| m.is_a?(Class) }
        models = models.flatten.map(&:to_s).reject(&:blank?)
        @observed_class_names = models.map(&:underscore).map(&:freeze).reject(&:blank?).uniq
      end

      # Returns an array of underscored class names to observe.
      #
      #   AccountObserver.observed_class_names # => ["account"]
      #
      # You can override this instead of using the +observe+ helper.
      #
      #   class AuditObserver < ActiveModel::Observer
      #     def self.observed_class_names
      #       ["account", "balance"]
      #     end
      #   end
      def observed_class_names
        return @observed_class_names.to_a if defined?(@observed_class_names)
        default_observed_class
      end

      def observed_classes
        ActiveSupport::Deprecation.warn(".observed_classes is deprecated for future removal, prefer observed_class_names to prevent autoloading of classes")
        observed_class_names.map { |name| name.to_s.camelize.constantize }.freeze
      end

      # Returns the class observed by default. It's inferred from the observer's
      # class name.
      #
      #   PersonObserver.default_observed_class  # => ["person"]
      #   AccountObserver.default_observed_class # => ["account"]
      def default_observed_class
        return @default_observed_class if defined?(@default_observed_class)
        class_name = self.name.underscore.sub(/\A(.*)_observer\z/, '\1')
        @default_observed_class = [class_name.freeze].freeze
      end

      def observed_class
        ActiveSupport::Deprecation.warn(".observed_class is deprecated for future removal, prefer default_observed_class to prevent autoloading of classes")
        default_observed_class.first.to_s.camelize.constantize
      end
    end

    delegate :observed_class_names, :observed_classes, :to => :class

    # Send observed_method(object) if the method exists and
    # the observer is enabled for the given object's class.
    def update(observed_method, object, *extra_args, &block) #:nodoc:
      return if !respond_to?(observed_method) || disabled_for?(object)
      send(observed_method, object, *extra_args, &block)
    end

    # Special method sent when a new class is created in the ORM, allow
    # this observer to observe the class if it's known to it.
    def try_hook!(klass)
      return if klass.name.nil?
      return unless observed_class_names.include?(klass.name.underscore)
      observe!(klass)
    end

    # Special method sent by the observed class when it is inherited.
    # Passes the new subclass.
    def observed_class_inherited(subclass) #:nodoc:
      self.class.observe(observed_class_names + [subclass])
      observe!(subclass)
    end

  protected
    def observe!(klass) #:nodoc:
      klass.add_observer(self)
    end

    # Returns true if notifications are disabled for this object.
    def disabled_for?(object) #:nodoc:
      klass = object.class
      return false unless klass.respond_to?(:observers)
      klass.observers.disabled_for?(self)
    end
  end
end
