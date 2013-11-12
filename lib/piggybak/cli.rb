require 'thor'

module Piggybak
  class CLI < Thor
    include Thor::Actions
  
    desc "install", "install and configure piggybak"
    def install
      if already_installed?
        update
      else        
        run('bundle install')
        run('rake piggybak_engine:install:migrations')
        run('rake db:migrate')
        mount_piggybak_route
        add_javascript_include_tag
        welcome
      end
    end
    
    desc "update", "update piggybak"
    def update
      say "Piggybak install detected"
      say "Updating current Piggybak install"
      run('rake piggybak_engine:install:migrations')
      say_upgraded
    end

    desc "mount_piggybak_route", "mount piggybak route"
    def mount_piggybak_route
      insert_into_file "config/routes.rb", "\n  mount Piggybak::Engine => '/checkout', :as => 'piggybak'\n", :after => "Application.routes.draw do\n"
    end
  
    desc "add_javascript_include_tag", "add javascript include tag to application layout"
    def add_javascript_include_tag
      jit_code_block = <<-eos
          \n  <% if "\#{params[:controller]}#\#\{params[:action]\}" == "piggybak/orders#submit" -%>
      <%= javascript_include_tag "piggybak/piggybak-application" %>\n  <% end -%>
      eos
      begin
        layout = 'app/views/layouts/application.html.erb'
        insert_into_file layout, jit_code_block, :after => "<%= javascript_include_tag \"application\" %>"
      rescue Errno::ENOENT
        error "We couln't find the layout file #{layout.inspect}"
        error "Don't forget to add the following code (use your equivalent to ERB) to your layout:"
        error jit_code_block
        error ""
        error ""
      end
    end
    
    desc "welcome", "invite to piggybak"
    def welcome
      say ""
      say ""
      say ""
      say "******************************************************************"
      say "******************************************************************"
      say "Piggybak Successfully Installed!"
      say "******************************************************************"
      say ""
      say "Add acts_as_sellable to any model that will be a sellable item."
      say ""
      say "class Product < ActiveRecord::Base"
      say "  acts_as_sellable"
      say "end"
    end
    
    desc "say_upgraded", "piggybak upgraded"
    def say_upgraded
      say ""
      say ""
      say ""
      say "******************************************************************"
      say "******************************************************************"
      say "Piggybak Successfully Upgraded!"
      say "******************************************************************"
    end
    
    private
    
    def already_installed?
      open('config/routes.rb') { |f| f.grep(/Piggybak\:\:Engine/) }.any?
    end
    
    
  end
end
