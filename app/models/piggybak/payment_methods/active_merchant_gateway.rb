module Piggybak
  module PaymentMethods
    class ActiveMerchantGateway < PaymentMethod
      # TODO: implement proprer ActiveMerchant gateway communication (payment branch)
      validates_presence_of :gateway_klass
      validate :gateway_must_be_supported

      attr_accessible :gateway_klass

      protected
        def gateway_must_be_supported
          if gateway_klass.present? && !supported_gateways.include?(gateway_klass)
            errors.add(:gateway_klass, "is not supported")
          end
        end
        
        def supported_gateways
          Piggybak.config.activemerchant_gateways
        end
    end
  end
end
