require_dependency 'user_import'
 
module RedmineUserImport

  module UserImport

    def build_object(row, item)
      # call build_object of UserImport and add the following tasks 
      user = super(row, item)

      # generate login if not exist
      user.login = user.mail.split("@").first.downcase if user.login == nil
      
      if Redmine::Plugin.installed?(:redmine_organizations)
	      if organization_name = row_value(row, 'organization')
	        if organization = Organization.find_by_identifier(organization_name.parameterize)
	          attributes['organization_id'] = organization.id
	        elsif create_organizations?
	          organization = Organization.new
	          organization.name = organization_name
	          if organization.save
	            attributes['organization_id'] = organization.id
	          end
	        end
	      end
	      user.organization = organization if organization.present?
	    end

	    # check if user is already present
	    known_user = User.joins(:email_addresses).where('LOWER(email_addresses.address) = ?', row_value(row, 'mail').downcase.strip).first
	    if known_user.present?
	      updated_users << known_user
	      known_user.update_attribute(:organization_id, organization.id) if organization.present? && Redmine::Plugin.installed?(:redmine_organizations)
	    else
	      #add callback for new users
	      add_callback(item.position, 'notify_by_mail') if self.settings["notifications"] == "1"
	    end     
	    user

    end

    #Returns the objects that were imported
	  def saved_objects
	    object_ids = saved_items.pluck(:obj_id)
	    User.where(id: object_ids).sorted
	  end

	  def updated_users
    	@updated_users ||= []
    end

    # Returns true if missing organizations should be created during the import
	  def create_organizations?
	    mapping['create_organizations'] == '1'
	  end

	  # Callback that notify each user by email with his password
	  def notify_by_mail_callback(user)
	    Mailer.deliver_account_information(user, user.password)
	  end
  
  end

end

UserImport.prepend RedmineUserImport::UserImport

# Redefine class method authorized?
class UserImport < Import
  def self.authorized?(user)
    user.allowed_to?(:users_import, nil, :global => true)
  end
end