require 'active_record'
require 'rails/observers/active_model'
require 'rails/observers/active_record/observer'

module ActiveRecord
  class Base
    extend ActiveModel::Observing::ClassMethods
    include ActiveModel::Observing
  end
end
