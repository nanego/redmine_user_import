require "rails_helper"
require "spec_helper"

#for add the folder of fixture in the same plugin
RSpec.configure do |config|
  config.fixture_path = __dir__+"/../fixtures"
end

RSpec.describe UserImportsController, :type => :controller do
	fixtures :users, :email_addresses,:members , :member_roles, :roles, :projects, :organizations, :functions
	render_views

	before do
    User.current = nil
    @request.session[:user_id] = 1    # user admin
  end

  it "should_not_authorized_to_access_this_page_user_with_permission" do
    get :new
    assert_response :success
  end

	it "new_should_display_the_upload_form" do
		get :new
    assert_response :success
    assert_select 'input[name=?]', 'file'
	end

	it "create_should_save_the_file" do
		import_count = UserImport.count
    post :create, :params => {
      :file => uploaded_test_file('import_users.csv', 'text/csv')
    }

    import = UserImport.last

    expect(import.user_id).to eq(@request.session[:user_id])
    expect(UserImport.count).to eq(import_count + 1)
    assert import.file_exists?
    assert_match /\A[0-9a-f]+\z/, import.filename
    assert_response 302
	end

  it "get_settings_should_display_settings_form" do
    import = generate_import
    get :settings, :params => {
        :id => import.to_param
      }
    assert_response :success
    assert_select 'select[name=?]', 'import_settings[separator]'
    assert_select 'select[name=?]', 'import_settings[wrapper]'
    assert_select 'select[name=?]', 'import_settings[encoding]'
  end

  it "post_settings_should_update_settings" do
    import = generate_import

    post :settings, :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ":",
          :wrapper => "|",
          :encoding => "UTF-8",
        }
      }
    assert_redirected_to "/user_imports/#{import.to_param}/mapping"

    import.reload
    expect(import.settings['separator']).to eq(":")
    expect(import.settings['wrapper']).to eq("|")
    expect(import.settings['encoding']).to eq("UTF-8")
    expect(import.total_items).to eq(2)
  end

  it "get_mapping_should_display_mapping_form" do
    import = generate_import
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
    import.save!

    get :mapping, :params => {
      :id => import.to_param
    }

    assert_response :success
    assert_select 'select[name=?]', 'import_settings[mapping][login]' do
      assert_select 'option', 6
      assert_select 'option[value="0"]', :text => 'login'
      assert_select 'option[value="1"]', :text => 'lastname'
      assert_select 'option[value="2"]', :text => 'firstname'
      assert_select 'option[value="3"]', :text => 'mail'
      assert_select 'option[value="4"]', :text => 'Organization'
    end

     assert_select 'table.sample-data' do
       assert_select 'tr', 3
       assert_select 'td', 15
     end
  end

  it "get_mapping_should_display_mapping_memberships_form" do
    import = generate_import
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
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

    function_count = Function.count
    assert_select 'select[name=?]', 'import_settings[memberships][functions][]' do
      assert_select 'option', function_count
    end

  end

   it "get_run_should_display_import_progress" do
    import = generate_import_with_mapping

    get :run, :params => {
        :id => import
      }
    assert_response :success
    assert_select '#import-progress'
  end

  it "run_should_add_two_users_assignment_to_projects_specified _technical_functional_roles_and_display_assignments_history_project" do
    member_count_before = Member.count
    member_role_count_before = MemberRole.count
    user_count_before = User.count

    import = generate_import_with_mapping
    import.settings['memberships'] = {"projects"=>["1", "3"], "roles"=>["1", "2"], "functions"=>["1"]}
    import.save!
    post :run, :params => {
      :id => import
    }
    import.reload

    member_count_after = Member.count
    member_role_count_after = MemberRole.count
    user_count_after = User.count

    assert_equal true, import.finished
    expect(import.total_items).to eq(2)
    expect(import.type).to eq('UserImport')
    #check assignment to projects specified during import with addition of technical and functional roles
    expect(member_count_after).to eq(member_count_before + 4)
    expect(member_role_count_after).to eq(member_role_count_before + 8)
    expect(MemberFunction.count).to eq(4)
    expect(user_count_after).to eq(user_count_before + 2)
    expect(UserImport.count).to eq(1)
    expect(ImportItem.count).to eq(2)
    expect(Journal.count).to eq(2)
    expect(JournalDetail.count).to eq(4)

    assert_redirected_to "/user_imports/#{import.to_param}"

  end

  it "should_show_without_errors" do
    import = generate_import_with_mapping
    import.run
    assert_equal 0, import.unsaved_items.count

    get :show, :params => {
        :id => import.to_param
      }
    assert_response :success

    assert_select 'ul#saved-items li', import.saved_items.count
    assert_select 'table#unsaved-items', 0
  end

  it "should_show_with_errors_unsaved_items_when_import_user_exist" do
    import = generate_import_with_mapping('import_users_exists.csv')
    import.run

    get :show, :params => {
        :id => import.to_param
      }

    assert_response :success
    expect(import.saved_items.count).to eq(1)
    expect(import.unsaved_items.count).to eq(1)
    assert_select 'table#unsaved-items tbody tr', 1

  end

end