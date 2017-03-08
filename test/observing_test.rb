require 'helper'
require 'active_model'
require 'rails/observers/active_model'

class ObservedModel
  include ActiveModel::Observing

  class Observer
  end
end

class FooObserver < ActiveModel::Observer
  class << self
    public :new
  end

  attr_accessor :stub

  def on_spec(record, *args)
    stub.event_with(record, *args) if stub
  end

  def around_save(record)
    yield :in_around_save
  end
end

class Foo
  include ActiveModel::Observing
end

class ObservingTest < ActiveModel::TestCase
  def setup
    ObservedModel.observers.clear
  end

  def teardown
    FooObserver.class_eval do
      remove_instance_variable :@observed_class_names if defined?(@observed_class_names)
      remove_instance_variable :@default_observed_class if defined?(@default_observed_class)
    end
  end

  test "initializes model with no cached observers" do
    assert ObservedModel.observers.empty?, "Not empty: #{ObservedModel.observers.inspect}"
  end

  test "stores cached observers in an array" do
    ObservedModel.observers << :foo
    assert ObservedModel.observers.include?(:foo), ":foo not in #{ObservedModel.observers.inspect}"
  end

  test "flattens array of assigned cached observers" do
    ObservedModel.observers = [[:foo], :bar]
    assert ObservedModel.observers.include?(:foo), ":foo not in #{ObservedModel.observers.inspect}"
    assert ObservedModel.observers.include?(:bar), ":bar not in #{ObservedModel.observers.inspect}"
  end

  test "uses an ObserverArray so observers can be disabled" do
    ObservedModel.observers = [:foo, :bar]
    assert ObservedModel.observers.is_a?(ActiveModel::ObserverArray)
  end

  test "instantiates observer names passed as strings" do
    ObservedModel.observers << 'foo_observer'
    FooObserver.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "instantiates observer names passed as symbols" do
    ObservedModel.observers << :foo_observer
    FooObserver.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "instantiates observer classes" do
    ObservedModel.observers << ObservedModel::Observer
    ObservedModel::Observer.expects(:instance)
    ObservedModel.instantiate_observers
  end

  test "raises an appropriate error when a developer accidentally adds the wrong class (i.e. Widget instead of WidgetObserver)" do
    assert_raise ArgumentError do
      ObservedModel.observers = ['string']
      ObservedModel.instantiate_observers
    end
    assert_raise ArgumentError do
      ObservedModel.observers = [:string]
      ObservedModel.instantiate_observers
    end
    assert_raise ArgumentError do
      ObservedModel.observers = [String]
      ObservedModel.instantiate_observers
    end
  end

  test "passes observers to subclasses" do
    FooObserver.instance
    bar = Class.new(Foo)
    assert_equal Foo.observers_count, bar.observers_count
  end
end

class ObserverTest < ActiveModel::TestCase
  def setup
    ObservedModel.observers = :foo_observer
  end

  def teardown
    FooObserver.class_eval do
      remove_instance_variable :@observed_class_names if defined?(@observed_class_names)
      remove_instance_variable :@default_observed_class if defined?(@default_observed_class)
    end
  end

  test "guesses implicit observable model name" do
    assert_equal ['foo'], FooObserver.default_observed_class
  end

  test "guesses implicit observable model name (compatibility)" do
    assert_equal Foo, FooObserver.observed_class
  end

  test "tracks implicit observable models" do
    instance = FooObserver.new
    assert_equal ['foo'], instance.observed_class_names
  end

  test "tracks implicit observable models (compatibility)" do
    instance = FooObserver.new
    assert_equal [Foo], instance.observed_classes
  end

  test "does not permit observing model class" do
    assert_raise(ArgumentError) { FooObserver.observe ObservedModel }
  end

  test "tracks explicit observed model as string" do
    FooObserver.observe 'observed_model'
    instance = FooObserver.new
    assert_equal ['observed_model'], instance.observed_class_names
  end

  test "tracks explicit observed model as symbol" do
    FooObserver.observe :observed_model
    instance = FooObserver.new
    assert_equal ['observed_model'], instance.observed_class_names
  end

  test "calls existing observer event" do
    foo = Foo.new
    FooObserver.instance.stub = stub
    FooObserver.instance.stub.expects(:event_with).with(foo)
    FooObserver.instance.try_hook! Foo
    Foo.notify_observers(:on_spec, foo)
  end

  test "calls existing observer event from the instance" do
    foo = Foo.new
    FooObserver.instance.stub = stub
    FooObserver.instance.stub.expects(:event_with).with(foo)
    FooObserver.instance.try_hook! Foo
    foo.notify_observers(:on_spec)
  end

  test "passes extra arguments" do
    foo = Foo.new
    FooObserver.instance.stub = stub
    FooObserver.instance.stub.expects(:event_with).with(foo, :bar)
    FooObserver.instance.try_hook! Foo
    Foo.send(:notify_observers, :on_spec, foo, :bar)
  end

  test "skips nonexistent observer event" do
    foo = Foo.new
    Foo.notify_observers(:whatever, foo)
  end

  test "update passes a block on to the observer" do
    yielded_value = nil
    FooObserver.instance.update(:around_save, Foo.new) do |val|
      yielded_value = val
    end
    assert_equal :in_around_save, yielded_value
  end

  test "observe redefines observed_classes class method" do
    class BarObserver < ActiveModel::Observer
      observe :foo
    end

    assert_equal [Foo], BarObserver.observed_classes

    BarObserver.observe(:observed_model)
    assert_equal [ObservedModel], BarObserver.observed_classes
  end
end
