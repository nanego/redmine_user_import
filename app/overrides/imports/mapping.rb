Deface::Override.new :virtual_path  => 'imports/mapping',
                     :name          => "Add-fields-memberships",
                     :insert_before => "p:first",
                     :text          => <<EOF
<fieldset class="box tabular">
    <legend><%= l(:label_import_to_projects) %></legend>
    <div>
      <%= render :partial => 'imports/fields_memberships' %>
    </div>
  </fieldset>
EOF