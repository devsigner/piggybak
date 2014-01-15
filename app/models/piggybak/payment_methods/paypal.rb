module Piggybak 
  module PaymentMethods
    class Paypal < PaymentMethod
      include ActiveMerchant::Billing::Integrations

      self.required_settings = [:email]
      
      class_attribute :default_params
      self.default_params = {
        cmd: '_cart',
        upload: 1,
        no_note: 1,
        no_shipping: 1,
        currency_code: -> { Piggybak::Config.default_currency },
        lc: -> { I18n.locale.to_s.sub(/-(.*)$/, '').upcase }
      }
      
      delegate :service_url, to: "ActiveMerchant::Billing::Integrations::Paypal"
      
      # FIXME: the URL needs to be signed for security reasons (payment branch)
      def gateway_url(order, controller)
        params = {
          business: settings[:email],
          invoice: order_invoice(order),
          return: return_url(order, controller),
          cancel_return: cancel_url(order, controller),
          notify_url: notify_url(order, controller)
        }
        
        default_params.each do |key, value|
          params[key] ||= Proc === value ? value.call : value
        end
        
        index = add_line_items(params, order.line_items.sellables)
        add_shipping_fees(params, order.line_items.shipments.first, index)
        
        "#{service_url}?#{params.to_query}"
      end
      
      def valid_notification?(order, request)
        # TODO: implement validation using ActiveMerchant
        notification = ActiveMerchant::Billing::Integrations::Paypal::Notification.new(request.raw_post)
        if Rails.env.development? || notification.acknowledge
          notification.complete? and money_order_in_cents( order ) == notification.amount
        end
      end

      def handle_request(order, controller)
        controller.redirect_to gateway_url(order, controller)
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
        "paypal"
      end
      
      protected
        def add_line_items(params, line_items)
          i = 1
          line_items.each do |li|
            params.update(
              "item_name_#{i}" => line_item_name(li),
              "item_number_#{i}" => li.sellable.id,
              "quantity_#{i}" => li.quantity,
              "amount_#{i}" => to_amount(li.price)
            )
            i += 1
          end
          i
        end
        
        def add_shipping_fees(params, shipment, i)
          params.update(
            "item_name_#{i}" => I18n.t("piggybak.orders.shipping_fees"),
            "amount_#{i}" => to_amount(shipment.price)
          )
        end
        
        def order_invoice(order)
          order.id
        end

        def money_order_in_cents( order )
          Money.new(order.total_due * 100, -> { Piggybak::Config.default_currency }.call)
        end

        def line_item_name(line_item)
          line_item.sellable.sku
        end
        
        def to_amount(price)
          price.to_f
        end
    end
  end
end
