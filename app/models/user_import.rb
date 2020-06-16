class UserImport < Import

  # Returns the objects that were imported
  def saved_objects
    object_ids = saved_items.pluck(:obj_id)
    User.where(id: object_ids).sorted
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

    if login = row_value(row, 'login')
      attributes['login'] = login
    else
      attributes['login'] = row_value(row, 'mail').split("@").first.downcase
    end

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

    user.send :safe_attributes=, attributes

    user
  end

end
