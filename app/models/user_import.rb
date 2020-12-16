class UserImport < Import

  # Returns the objects that were imported
  def saved_objects
    object_ids = saved_items.pluck(:obj_id)
    User.where(id: object_ids).sorted
  end

  def unsaved_objects
    User.where(id: @user_ids).sorted
  end

  # Returns true if missing organizations should be created during the import
  def create_organizations?
    mapping['create_organizations'] == '1'
  end

  private

  def build_object(row, item)
    user = User.new

    attributes = {
        'firstname' => row_value(row, 'firstname'),
        'lastname' => row_value(row, 'lastname'),
        'mail' => row_value(row, 'mail')
    }

    user.send :safe_attributes=, attributes

    attributes = {}
   
    @user_ids ||= [] 

    if login = row_value(row, 'login')
      attributes['login'] = login
    else
      if row_value(row, 'mail').present?
        attributes['login'] = row_value(row, 'mail').split("@").first.downcase
      else
        ""
      end
    end

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
    end

    user.send :safe_attributes=, attributes

    # check if user or email is found
    userFound = User.where(:login => attributes['login'])
    emailFound = EmailAddress.where(:address => row_value(row, 'mail'))
    unless userFound.empty? && emailFound.empty?
      if userFound.empty?
        userId = emailFound.first.user_id
        userFound = User.where(:id => userId)
      end
      @user_ids<<userFound.first.id
      # update the organization of user
      userFound.first.update_attribute(:organization,  organization) if Redmine::Plugin.installed?(:redmine_organizations)
    end

    user
  end

end
