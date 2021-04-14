require "spec_helper"

def upload_user_test_file(name, mime)
  fixture_file_upload(__dir__ + "/../files/#{name}", mime, true)
end

def generate_user_import(fixture_name = 'import_users.csv')
  import = UserImport.new
  import.user_id = 1
  import.file = upload_user_test_file(fixture_name, 'text/csv')
  import.save!
  import
end

def generate_user_import_with_mapping(fixture_name = 'import_users.csv')
  import = generate_user_import(fixture_name)

  import.settings = {
    'separator' => ';', 'wrapper' => '"', 'encoding' => 'UTF-8', "notifications" => "0",
    'mapping' => {
      'login' => '1',
      'firstname' => '2',
      'lastname' => '3',
      'mail' => '4',
      'language' => '5',
      'admin' => '6',
      'auth_source' => '7',
      'password' => '8',
      'must_change_passwd' => '9',
      'status' => '10',
      "phone_number" => "11",
      "organization" => "12",
      "create_organizations" => "0"
    }
  }
  import.save!
  import
end

def organizations_plugin_installed?
  Redmine::Plugin.installed?(:redmine_organizations)
end
