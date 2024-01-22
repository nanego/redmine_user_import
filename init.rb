require_relative 'lib/redmine_user_import/hooks'

Redmine::Plugin.register :redmine_user_import do
  name 'Redmine User Import plugin'
  author 'Vincent ROBERT'
  description 'This is a plugin for Redmine which allows you to easily create new user accounts from CSV files'
  version '0.0.1'
  url 'https://github.com/nanego/redmine_user_import'
  requires_redmine_plugin :redmine_base_rspec, :version_or_higher => '0.0.4' if Rails.env.test?
  requires_redmine_plugin :redmine_base_deface, :version_or_higher => '0.0.1'

  permission :users_import, { :controller => 'user_imports' }
end
