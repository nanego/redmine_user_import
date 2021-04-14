require "spec_helper"
require File.dirname(__FILE__) + "/../support/import_spec_helpers"

RSpec.describe ImportsController, :type => :controller do
  render_views

  fixtures :users, :email_addresses, :members, :member_roles, :roles, :projects
  fixtures :organizations if Redmine::Plugin.installed?(:redmine_organizations)
  fixtures :functions if Redmine::Plugin.installed?(:redmine_limited_visibility)

  let!(:existing_user) { User.find(3) }

  before do
    User.current = nil
    @request.session[:user_id] = 1 # user admin
  end

  it "should_authorized_to_access_this_page" do
    get(:new, :params => {:type => 'UserImport'})
    assert_response :success
  end

  it "should_not_authorized_to_access_this_page_user_without_permission" do
    User.current = nil
    @request.session[:user_id] = 7

    get(:new, :params => {:type => 'UserImport'})
    assert_response 403
  end

  it "shoud_display_permission_users_import"do
    permission_array = Redmine::AccessControl.permissions.to_a.map(&:name)
    expect(permission_array).to include(:users_import)
  end
  
	it "new_should_display_the_upload_form" do
		get(:new, :params => {:type => 'UserImport'})
    assert_response :success
    assert_select 'input[name=?]', 'file'
  end

  it "create_should_save_the_file" do
    import_count = UserImport.count
    post :create, :params => {
      :type => 'UserImport',
      :file => upload_user_test_file('import_users.csv', 'text/csv')
    }

    import = UserImport.last

    expect(import.user_id).to eq(@request.session[:user_id])
    expect(UserImport.count).to eq(import_count + 1)
    assert import.file_exists?
    assert_match /\A[0-9a-f]+\z/, import.filename
    assert_response 302
  end

  context "import new users" do

    let!(:import) { generate_user_import }

    it "get_settings_should_display_settings_form" do
      get :settings, :params => {
        :id => import.to_param
      }
      assert_response :success
      assert_select 'select[name=?]', 'import_settings[separator]'
      assert_select 'select[name=?]', 'import_settings[wrapper]'
      assert_select 'select[name=?]', 'import_settings[encoding]'
      assert_select 'input[name=?]', 'import_settings[notifications]'
    end

    it "post_settings_should_update_settings" do
      post :settings, :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ":",
          :wrapper => "|",
          :encoding => "UTF-8",
          :notifications => "1",
        }
      }
      assert_redirected_to "/imports/#{import.to_param}/mapping"

      import.reload
      expect(import.settings['separator']).to eq(":")
      expect(import.settings['wrapper']).to eq("|")
      expect(import.settings['encoding']).to eq("UTF-8")
      expect(import.settings['notifications']).to eq("1")
      expect(import.total_items).to eq(2)
    end

    it "get_mapping_should_display_mapping_form" do
      import.settings = { 'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1" }
      import.save!

      get :mapping, :params => {
        :id => import.to_param
      }

      assert_response :success
      assert_select 'select[name=?]', 'import_settings[mapping][login]' do
        assert_select 'option', 14
        assert_select 'option[value="1"]', :text => 'login'
        assert_select 'option[value="2"]', :text => 'firstname'
        assert_select 'option[value="3"]', :text => 'lastname'
        assert_select 'option[value="4"]', :text => 'mail'
        assert_select 'option[value="12"]', :text => 'Organization'
      end

      assert_select 'table.sample-data' do
        assert_select 'tr', 3
        assert_select 'td', 39
      end
    end

    it "get_mapping_should_display_mapping_memberships_form" do
      import.settings = { 'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1" }
      import.save!

      get :mapping, :params => {
        :id => import.to_param
      }
      assert_response :success
      if User.current.admin?
        project_count = Project.active.count
      else
        project_count = Project.all_public.active.count
      end

      assert_select 'select[name=?]', 'import_settings[memberships][projects][]' do
        assert_select 'option', project_count
      end

      role_count = Role.givable.count
      assert_select 'select[name=?]', 'import_settings[memberships][roles][]' do
        assert_select 'option', role_count
      end

      if Redmine::Plugin.installed?(:redmine_limited_visibility)
        function_count = Function.count
        assert_select 'select[name=?]', 'import_settings[memberships][functions][]' do
          assert_select 'option', function_count
        end
      end

    end

  end

  context "import users with mapping" do

    let!(:import) { generate_user_import_with_mapping }

    def run_import_with_memberships(csv_file = nil)
      if csv_file
        import = generate_user_import_with_mapping(csv_file)
      else
        import = generate_user_import_with_mapping
      end
      import.settings['memberships'] = { "projects" => ["1", "3"], "roles" => ["1", "2"], "functions" => ["1"] }
      import.save!
      post :run, :params => {
        :id => import
      }
      import.reload
    end

    it "get_run_should_display_import_progress" do

      get :run, :params => {
        :id => import
      }
      assert_response :success
      assert_select '#import-progress'
    end

    it "run_should_add_users" do
      expect {
        run_import_with_memberships
      }.to change { User.count }.by(2)
    end

    it "run_should_add_members" do
      expect {
        run_import_with_memberships
      }.to change { Member.count }.by(4)
    end

    it "run_should_assigne_to_projects_specified_technical_roles" do
      expect {
        run_import_with_memberships
      }.to change { MemberRole.count }.by(8)
    end

    it "run_should_assigne_to_projects_specified_functional_roles" do
      expect {
        run_import_with_memberships
      }.to change { MemberFunction.count }.by(4) if Redmine::Plugin.installed?(:redmine_limited_visibility)
    end

    it "run_should_check_import_object" do
      import.settings['memberships'] = { "projects" => ["1", "3"], "roles" => ["1", "2"], "functions" => ["1"] }
      import.save!
      post :run, :params => {
        :id => import
      }
      import.reload

      expect(import.finished).to be_truthy
      expect(import.total_items).to eq 2
      expect(import.type).to eq 'UserImport'
      expect(UserImport.count).to eq 1
      expect(ImportItem.count).to eq 2
      expect(Journal.count).to eq(2) if Redmine::Plugin.installed?(:redmine_admin_activity)
      expect(JournalDetail.count).to eq(4) if Redmine::Plugin.installed?(:redmine_admin_activity)
      assert_redirected_to "/imports/#{import.to_param}"
    end

    it "should_show_without_errors" do
      import.run
      
      assert_equal 0, import.unsaved_items.count

      get :show, :params => {
        :id => import.to_param
      }
      assert_response :success

      assert_select 'table#saved-items tbody tr', 2
      assert_select 'table#unsaved-items', 0
    end

    it "should_show_with_errors_unsaved_items_when_import_user_exist" do
      import = run_import_with_memberships('import_users_exists.csv')
      get :show, :params => {
        :id => import.to_param
      }
      assert_response :success
      expect(import.saved_items.count).to eq(1)
      expect(import.unsaved_items.count).to eq(1)
      assert_select 'table#unsaved-items tbody tr', 1
    end

    context "updating existing users" do

      let!(:project_1) { Project.find(1) }
      let!(:role_manager) { Role.find(1) }
      let!(:role_developer) { Role.find(2) }

      it "adds some roles to a user" do
        expect(existing_user.roles_for_project(project_1)).to eq [role_developer]

        run_import_with_memberships('import_users_exists.csv')
        existing_user.reload

        expect(existing_user.roles_for_project(project_1)).to eq [role_manager, role_developer]
      end

      if Redmine::Plugin.installed?(:redmine_limited_visibility)
        let!(:function_1) { Function.find(1) }

        it "adds some functions to a user" do
          expect(existing_user.functions_for_project(project_1)).to be_empty

          run_import_with_memberships('import_users_exists.csv')
          existing_user.reload

          expect(existing_user.functions_for_project(project_1)).to eq [function_1]
        end
      end

    end

  end

  context "import users with option notification" do
    before { ActionMailer::Base.deliveries.clear }

    def run_import_with_option_notification(fixture_name = 'import_users.csv', notify)
      import = generate_user_import_with_mapping(fixture_name)
      import.settings['notifications'] = notify
      import.save!
      post :run, :params => {
        :id => import
      }      
      import.reload
    end

    it "run_should_not_notify_users_by_mail_if_notification_unselected" do
      run_import_with_option_notification('0')
      # Even if we do not enable the option to send alerts during import, we will send two mails because an administrator user is present
      # First mail for admin, second for user imported as admin
      expect(ActionMailer::Base.deliveries.count).to eq(2)
    end
    
    it "run_should_notify_users_by_mail_if_notification_selected" do
      run_import_with_option_notification('1')
      user = User.order('id DESC').first
      mail = ActionMailer::Base.deliveries.last
      # Here there are 4 mails, 2 mails because of add user as admin , 2 mails because of import 2 users
      expect(ActionMailer::Base.deliveries.count).to eq(4)
      expect(mail).to be_truthy

      expect(mail.bcc).to include(user.mail)
      expect(mail.subject).to eq("Your Redmine account activation")
      expect(mail.body.to_yaml).to include("Your account information")
      expect(mail.body.to_yaml).to include("Login")
      expect(mail.body.to_yaml).to include("password")
      expect(mail.body.to_yaml).to include("Sign in")
    end

    it "run_should_notify_just_new_users_by_mail_if_notification_selected" do
      run_import_with_option_notification('import_users_exists.csv','1')
      user = User.order('id DESC').first
      mail = ActionMailer::Base.deliveries.last

      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(mail).to be_truthy

      expect(mail.bcc).to include(user.mail)
      expect(mail.subject).to eq("Your Redmine account activation")
      expect(mail.body.to_yaml).to include("Your account information")
      expect(mail.body.to_yaml).to include("Login")
      expect(mail.body.to_yaml).to include("password")
      expect(mail.body.to_yaml).to include("Sign in")
    end

  end

end
