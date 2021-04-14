Deface::Override.new :virtual_path  => 'imports/show',
                     :name          => "Add-view-user-imports",
                     :insert_after  => "erb[loud]:contains('_sidebar')",
                     :text          => <<EOF
<% if User.current.admin?%>
  <p><%= link_to l(:label_user_view_all), users_path(:set_filter => 1, :user_id => @import.saved_objects.map(&:id).join(',')) %></p>
  <p><%= link_to l(:label_user_imports), all_user_imports_path %></p>
<% end %>
EOF