module Piggybak 
  module PaymentMethods
    class WebsiteGateway < PaymentMethod
      def handle_request(order, controller)
        controller.redirect_to gateway_url(order, controller)
      end
      
      def gateway_url(order, controller)
        raise NotImplementedError, "subclasses must override `gateway_url'"
      end
      
      def valid_notification?(order, request)
        raise NotImplementedError, "subclasses must override `valid_notification'"
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
      
      def template_name
        "website_gateway"
      end
    end
  end
end
