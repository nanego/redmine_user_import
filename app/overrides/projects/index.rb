Deface::Override.new :virtual_path  => "projects/index",
                     :name          => "add-link-to-user-import",
                     :insert_bottom => "div.contextual",
                     :text          => "<%= link_to 'Import CSV', new_user_imports_path, :class=>'icon icon-download' if !User.current.admin? && User.current.allowed_to?(:users_import, nil, :global => true) %>"