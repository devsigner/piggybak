module Piggybak 
  class PaymentMethod < ActiveRecord::Base
    FILES = File.join(File.dirname(__FILE__), 'payment_methods', '*.rb')
    APP_FILES = File.join(Rails.root, 'app', 'models', 'payment_methods', '*.rb')

    # FIXME: should be renamed :payment_method_settings for clarity...
    has_many :payment_method_values, :dependent => :destroy

    class_attribute :required_settings, instance_writer: false
    self.required_settings = []

    accepts_nested_attributes_for :payment_method_values, :allow_destroy => true

    validates_presence_of :description
    validate :required_settings_must_be_specified

    attr_accessible :type, :active, :payment_method_values_attributes, :description

    scope :active, where(active: true)

    @@types_by_name = nil
    
    # { "Website Gateway" => "Piggybak::PaymentMethod::WebsiteGateway", ... }
    def self.types_by_name
      @@types_by_name ||= begin
        # Ensure all PaymentMethod subclasses are loaded
        Dir.glob("{#{FILES},#{APP_FILES}}").each(&method(:require))
        
        PaymentMethod.subclasses.map(&:name).each_with_object({}) do |class_name, types|
          types[class_name.demodulize.titleize] = class_name
        end
      end
    end

    # Hook with access to the OrdersController instance, executed after an order has been created
    # Allows to customize the flow, especially useful for web gateways (or pending payments)
    # By default, redirects to the receipt url
    def handle_request(order, controller)
      controller.redirect_to piggybak.receipt_url
    end

    # Allows RailsAdmin to present type names
    def type_enum
      PaymentMethod.types_by_name
    end

    def admin_label
      description
    end

    def template_name
      self.class.name.demodulize.underscore
    end

    def settings(reload = false)
      payment_method_values(reload).each_with_object({}) do |setting, settings|
        settings[setting.key.to_sym] = setting.value
      end
    end

    protected
      def required_settings_must_be_specified
        required_settings.each do |key|
          unless payment_method_values.any? { |setting| setting.key == key.to_s }
            errors.add(:payment_method_values, "#{key} is required")
          end
        end
      end
  end
end
