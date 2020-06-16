require 'csv'

class UserImportsController < ApplicationController
  menu_item :users

  before_action :find_import, :only => [:show, :settings, :mapping, :run]
  before_action :authorize_global

  helper :users
  helper :issues
  helper :queries
  helper :imports

  def new
  end

  def index
    @imports = UserImport.order('created_at desc')
  end

  def create
    @import = UserImport.new
    @import.user = User.current
    @import.file = params[:file]
    @import.set_default_settings

    if @import.save
      redirect_to user_import_settings_path(@import)
    else
      render :action => 'new'
    end
  end

  def show
  end

  def settings
    if request.post? && @import.parse_file
      redirect_to user_import_mapping_path(@import)
    end

  rescue CSV::MalformedCSVError, ArgumentError, EncodingError => e
    if e.is_a?(CSV::MalformedCSVError) && e.message !~ /Invalid byte sequence/
      flash.now[:error] = l(:error_invalid_csv_file_or_settings)
    else
      flash.now[:error] = l(:error_invalid_file_encoding, :encoding => ERB::Util.h(@import.settings['encoding']))
    end
  rescue SystemCallError => e
    flash.now[:error] = l(:error_can_not_read_import_file)
  end

  def mapping
    if request.post?
      respond_to do |format|
        format.html {
          if params[:previous]
            redirect_to user_import_settings_path(@import)
          else
            redirect_to user_import_run_path(@import)
          end
        }
        format.js # updates mapping form on project or tracker change
      end
    end
  end

  def run
    if request.post?
      @current = @import.run(
          :max_items => max_items_per_request,
          :max_time => 10.seconds
      )
      respond_to do |format|
        create_memberships if @import.finished?
        format.html {
          if @import.finished?
            redirect_to user_import_path(@import)
          else
            redirect_to user_import_run_path(@import)
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
      @import.saved_objects.each do |user|
        projects.each do |project|
          member = Member.new(user: user, project: project)
          member.roles = roles
          member.functions = functions if functions.present?
          member.save
        end
      end
    end
  end

  def find_import
    @import = UserImport.where(:filename => params[:id]).first
    if @import.nil?
      render_404
      return
    elsif @import.finished? && action_name != 'show'
      redirect_to user_import_path(@import)
      return
    end
    update_from_params if request.post?
  end

  def update_from_params
    if params[:import_settings].present?
      @import.settings ||= {}
      @import.settings.merge!(params[:import_settings].to_unsafe_hash)
      @import.save!
    end
  end

  def max_items_per_request
    5
  end
end
