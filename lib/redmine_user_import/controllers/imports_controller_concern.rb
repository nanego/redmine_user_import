require 'imports_controller' # only useful for Redmine < 5

module RedmineUserImport::Controllers::ImportsControllerConcern
  extend ActiveSupport::Concern

  def create_member_for_import_users(user, project, roles, functions = nil)
    member = Member.new(user: user, project: project)
    member.roles = roles
    member.functions = functions if functions.present?
    member.save
    add_member_creation_to_journal(member, roles.pluck(:id), functions.pluck(:id)) if Redmine::Plugin.installed?(:redmine_admin_activity)
  end

  def update_member_for_import_users(member, user, project, roles, functions = nil)
    previous_role_ids = member.role_ids
    previous_function_ids = member.function_ids if Redmine::Plugin.installed?(:redmine_limited_visibility)
    member.roles << (roles - member.roles)
    member.functions << (functions - member.functions) if functions.present?
    member.save

    if Redmine::Plugin.installed?(:redmine_admin_activity)
      unless (previous_role_ids.sort == member.roles.pluck(:id).sort && previous_function_ids.sort == member.functions.pluck(:id).sort)
        add_member_edition_to_journal(member, previous_role_ids, member.roles.pluck(:id), previous_function_ids, member.functions.pluck(:id))
      end
    end
  end
end

class ImportsController < ApplicationController
  include RedmineAdminActivity::Journalizable if Redmine::Plugin.installed?(:redmine_admin_activity)
  include RedmineUserImport::Controllers::ImportsControllerConcern

  def index
    @imports = UserImport.order('created_at desc')
  end

  def run
    if request.post?
      @current = @import.run(
        :max_items => max_items_per_request,
        :max_time => 10.seconds
      )
      respond_to do |format|
        create_memberships
        format.html {
          if @import.finished?
            redirect_to import_path(@import)
          else
            redirect_to import_run_path(@import)
          end
        }
        format.js
      end
    end
  end

  private

  def create_memberships

    return if @import.settings['memberships'].blank?

    projects = Project.where(id: @import.settings['memberships']['projects'])
    roles = Role.where(id: @import.settings['memberships']['roles'])
    functions = Function.where(id: @import.settings['memberships']['functions']) if Redmine::Plugin.installed?(:redmine_limited_visibility)

    if projects.present? && roles.present?

      if @import.finished?
        @import.saved_objects.each do |user|
          projects.each do |project|
            create_member_for_import_users(user, project, roles, functions)
          end
        end
      end
      # update the information of user who already existed
      @import.updated_users.each do |user|
        projects.each do |project|
          # check if member is exist
          member_found = Member.where(user: user, project: project)
          if member_found.empty?
            create_member_for_import_users(user, project, roles, functions)
          else
            member = member_found.first
            update_member_for_import_users(member, user, project, roles, functions)
          end
        end
      end
    end
  end

end
