Deface::Override.new :virtual_path  => "projects/index",
                     :name          => "add-link-to-user-import",
                     :insert_bottom => "div.contextual",
                     :text          => "<%= link_to l(:label_import_users_csv), new_user_imports_path, :class=>'icon icon-import' if User.current.allowed_to?(:users_import, nil, :global => true) %>"