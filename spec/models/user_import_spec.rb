require "spec_helper"
require File.dirname(__FILE__) + "/../support/import_spec_helpers"

describe UserImport, type: :model do

  fixtures :users, :email_addresses, :members, :member_roles, :roles, :projects
  fixtures :functions if Redmine::Plugin.installed?(:redmine_limited_visibility)
  if organizations_plugin_installed?
    fixtures :organizations
    let!(:org_a) { Organization.find(1) }
  end

  let!(:import_with_new_users) { generate_user_import_with_mapping }
  let!(:import_with_existing_users) { generate_user_import_with_mapping('import_users_exists.csv') }
  let!(:existing_user) { User.find(3) }

  it "should test_authorized" do
    role_developer = Role.find(2)
    role_developer.permissions<<:users_import
    role_developer.save
    assert  UserImport.authorized?(User.find(1))  # admins
    assert  UserImport.authorized?(User.find(2))  # user with permission user_import
    assert  !UserImport.authorized?(User.find(7)) # user does not have permission user_import
  end

  it "creates new users with according organization if any" do
    expect {
      import = import_with_new_users
      import.save!
      import.run
    }.to change { User.count }.by(2)

    if Redmine::Plugin.installed?(:redmine_organizations)
      added_users = User.last(2)
      expect(added_users.first.organization).to eq org_a
      expect(added_users.second.organization).to eq nil
    end
  end

  it "does not create new users if they already exist" do
    expect {
      import = import_with_existing_users
      import.save!
      import.run
    }.to change { User.count }.by(1)
    existing_user.reload
    expect(ImportItem.first.message).to eq("Email has already been taken\nLogin has already been taken")
    if Redmine::Plugin.installed?(:redmine_organizations)
      expect(User.last.organization).to eq(org_a)
      expect(existing_user.organization).to eq(org_a)
    end
  end

  it "removes the uploaded file" do
    import = import_with_new_users
    file_path = import.filepath
    assert File.exists?(file_path)

    import.run

    assert !File.exists?(file_path)
  end

end
