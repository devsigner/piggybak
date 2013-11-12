require 'piggybak/config'
require 'acts_as_sellable'
require 'acts_as_orderer'
require 'acts_as_changer'
require 'active_merchant'
require 'formatted_changes'
require 'currency'
require 'mask_submissions'
require 'rack-ssl-enforcer'

module Piggybak
  def self.config(entity = nil, &block)

    if entity
      Piggybak::Config.model(entity, &block)
    elsif block_given?
      block.call(Piggybak::Config)
    else
      Piggybak::Config
    end 
  end

  def self.reset
    Piggybak::Config.reset
  end

  class Engine < Rails::Engine
    initializer "piggybak.ssl_enforcer" do |app|
      # Note: If your main application also uses rack-ssl-enforcer,
      # append to Piggyak.config.extra_secure_paths
      # inside a before_initialize block
      if Piggybak.config.secure_checkout
        paths = [/^#{Piggybak.config.secure_prefix}\/checkout\/$/,
                 "#{Piggybak.config.secure_prefix}/checkout/orders/tax",
                 "#{Piggybak.config.secure_prefix}/checkout/orders/shipping",
                 "#{Piggybak.config.secure_prefix}/checkout/orders/geodata",
                 /^\/users$/,
                 "/users/sign_in",
                 "/users/sign_out",
                 "/users/sign_up"]
        Piggybak.config.extra_secure_paths.each do |extra_path|
          paths << [/^#{Piggybak.config.secure_prefix}#{extra_path}/]
        end
        app.config.middleware.use Rack::SslEnforcer,
          :only => paths,
          :strict => true
      end
    end
    
    initializer "piggybak.add_helper" do |app|
      ApplicationController.class_eval do
        helper :piggybak
      end
    end

    initializer "piggybak.precompile_hook", :group => :all do |app|
      app.config.assets.precompile += ['piggybak/piggybak-application.js']
    end

    # Needed for development
    config.to_prepare do
      Piggybak.config.line_item_types.each do |k, v|
        plural_k = k.to_s.pluralize.to_sym
        if v[:nested_attrs]
          Piggybak::LineItem.class_eval do
            # TODO: dependent destroy destroys all line items. Fix and remove after_destroy on line items
            has_one k, :class_name => v[:class_name] #, :dependent => :destroy
            accepts_nested_attributes_for k
            attr_accessible "#{k}_attributes".to_sym
          end
        end
        Piggybak::Order.class_eval do
          define_method "#{k}_charge" do
            self.line_items.send(plural_k).map(&:price).reduce(:+) || 0
          end
        end
      end
      Piggybak::Order.class_eval do
        has_many :line_items, :inverse_of => :order do
          Piggybak.config.line_item_types.each do |k, v|
            # Define proxy association method for line items
            # e.g. self.line_items.sellables
            # e.g. self.line_items.taxes
            define_method "#{k.to_s.pluralize}" do
              proxy_association.proxy.select { |li| li.line_item_type == "#{k}" && !li.marked_for_destruction? }
            end
          end
        end
        # Define method subtotal on order, alias to sellable_charge
        alias :subtotal :sellable_charge 
      end
    end
  end
end
