Deface::Override.new(virtual_path: 'spree/shared/_nav_bar',
                     name: 'typeahead_search',
                     insert_after: 'ul#nav-bar',
                     partial: 'spree/shared/typeahead_search',
                     disabled: false)
