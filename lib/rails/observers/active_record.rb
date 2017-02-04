require 'rails/observers/active_model'

module ActiveRecord
  autoload :Observer, 'rails/observers/active_record/observer'
end

require 'rails/observers/active_record/base'
