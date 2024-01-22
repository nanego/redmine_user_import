module RedmineUserImport
  module Hooks
    class ModelHook < Redmine::Hook::Listener
      def after_plugins_loaded(_context = {})
        require_relative 'controllers/imports_controller_concern'
        require_relative 'models/user_import'
      end
    end
  end
end
