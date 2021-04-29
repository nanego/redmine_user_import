Deface::Override.new :virtual_path => 'imports/_users_fields_mapping',
                     :name => 'add-user-organization',
                     :insert_bottom => "div.splitcontentleft",
                     :text => <<EOF 
 <p>
  <label for="import_mapping_category"><%= l(:field_organization) %></label>
  <%= mapping_select_tag @import, 'organization' %>
  <label class="block">
    <%= check_box_tag 'import_settings[mapping][create_organizations]', '0', false, disabled: true %>
    <%= l(:label_create_missing_values) %> <span style="color:grey;">(Fonctionnalité désactivée pour l'instant. Le référentiel des organisations doit être géré manuellement.)</span>
  </label>
</p>
EOF