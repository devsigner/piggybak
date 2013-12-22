module Piggybak 
  module PaymentMethods
    class WebsiteGateway < PaymentMethod
      def handle_request(order, controller)
        controller.redirect_to gateway_url(order, controller)
      end
      
      def gateway_url(order, controller)
        raise NotImplementedError, "subclasses must override `gateway_url'"
      end
      
      def return_url(order, controller)
        controller.piggybak.receipt_url
      end
      
      def cancel_url(order, controller)
        controller.piggybak.receipt_url
      end
      
      def notify_url(order, controller)
        controller.piggybak.notify_order_url(order.id)
      end
      
      def return_url(*)
        "http://www.example.com/"
      end
      alias_method :notify_url, :return_url
      alias_method :cancel_url, :return_url
      
      def template_name
        "website_gateway"
      end
    end
  end
end
