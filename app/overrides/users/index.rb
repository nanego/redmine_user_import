Deface::Override.new :virtual_path  => "users/index",
                     :name          => "add-link-to-user-import",
                     :insert_bottom => "div.contextual",
                     :text          => "<%= link_to 'Import CSV', new_user_imports_path, :class=>'icon icon-download' if User.current.admin? %>"
