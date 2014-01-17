module Piggybak
  class OrdersController < ApplicationController

    def submit
      response.headers['Cache-Control'] = 'no-cache'
      @cart = Piggybak::Cart.new(request.cookies["cart"])
      @payment_methods = PaymentMethod.active

      if request.post?
        create_order
      else
        @order = Piggybak::Order.new
        @order.create_payment_shipment
        @order.initialize_user(current_user)
      end
    end

    # FIXME: need to validate the integrity of the request (payment branch)
    # As is, it might be forged by the user
    def notify
      @order = Piggybak::Order.find(params[:id])
      if @order.payment_method.valid_notification?(@order, request)
        @order.paid!
        @order.deliver_order_confirmation
      else
        @order.failed!
      end
      render nothing: true
    end

    def pending
      @order = Piggybak::Order.find(params[:id])
    end

    def receipt
      response.headers['Cache-Control'] = 'no-cache'

      if !session.has_key?(:last_order)
        redirect_to '/' 
        return
      end

      @order = Piggybak::Order.find(session[:last_order])
    end

    def list
      redirect_to '/' if current_user.nil?
    end

    def download
      @order = Piggybak::Order.find(params[:id])

      render :layout => false
    end

    def email
      order = Piggybak::Order.find(params[:id])

        Piggybak::Notifier.order_notification(order).deliver
        flash[:notice] = "Email notification sent."
        OrderNote.create(:order_id => order.id, :note => "Email confirmation manually sent.", :user_id => current_user.id)

      redirect_to rails_admin.edit_path('Piggybak::Order', order.id)
    end

    def paid
      order = Piggybak::Order.find(params[:id])
      order.paid!

      redirect_to rails_admin.edit_path('Piggybak::Order', order.id)
    end

    def cancel
      order = Piggybak::Order.find(params[:id])

        order.recorded_changer = current_user.id
        order.disable_order_notes = true

        order.line_items.each do |line_item|
          if line_item.line_item_type != "payment"
            line_item.mark_for_destruction
          end
        end
        order.update_attribute(:total, 0.00)
        order.update_attribute(:to_be_cancelled, true)

        OrderNote.create(:order_id => order.id, :note => "Order set to cancelled. Line items, shipments, tax removed.", :user_id => current_user.id)
        
        flash[:notice] = "Order #{order.id} set to cancelled. Order is now in unbalanced state."

      redirect_to rails_admin.edit_path('Piggybak::Order', order.id)
    end

    # AJAX Actions from checkout
    def shipping
      cart = Piggybak::Cart.new(request.cookies["cart"])
      cart.set_extra_data(params)
      shipping_methods = Piggybak::ShippingMethod.lookup_methods(cart)
      render :json => shipping_methods
    end

    def tax
      cart = Piggybak::Cart.new(request.cookies["cart"])
      cart.set_extra_data(params)
      total_tax = Piggybak::TaxMethod.calculate_tax(cart)
      render :json => { :tax => total_tax }
    end

    def geodata
      countries = ::Piggybak::Country.find(:all, :include => :states)
      data = countries.inject({}) do |h, country|
        h["country_#{country.id}"] = country.states
        h
      end
      render :json => { :countries => data }
    end
    
    protected
      def create_order
        Piggybak::Order.transaction do
          @order = Piggybak::Order.new(params[:piggybak_order])
          @order.create_payment_shipment

          log { "Order received with params #{cleaned_order_params.inspect}" }
          @order.initialize_user(current_user)

          @order.ip_address = request.remote_ip
          @order.user_agent = request.user_agent
          @order.add_line_items(@cart)

          log { "Order contains: #{cookies["cart"]} for user #{current_user ? current_user.email : 'guest'}" }

          if @order.save
            log { "Order saved: #{@order.inspect}" }
            cookies["cart"] = { :value => '', :path => '/' }
            session[:last_order] = @order.id
            @order.handle_request(self)
          else
            log(:warn) { "Order failed to save #{@order.errors.full_messages} with #{@order.inspect}." }
          end
        end
      end
      
      def piggybak_logger
        @piggybak_logger ||= Logger.new("#{Rails.root}/#{Piggybak.config.logging_file}")
      end
      
      def log(level = :info)
        if Piggybak.config.logging
          message = "#{request.remote_ip}:#{Time.now.strftime("%Y-%m-%d %H:%M")} #{yield}"
          piggybak_logger.send(level, message)
        end
      end
      
      def cleaned_order_params
        clean_params = params[:piggybak_order].clone
        clean_params[:line_items_attributes].each do |k, li_attr|
          if li_attr[:line_item_type] == "payment" && li_attr.has_key?(:payment_attributes)
            if li_attr[:payment_attributes].has_key?(:number)
              li_attr[:payment_attributes][:number] = li_attr[:payment_attributes][:number].mask_cc_number
            end
            if li_attr[:payment_attributes].has_key?(:verification_value)
              li_attr[:payment_attributes][:verification_value] = li_attr[:payment_attributes][:verification_value].mask_csv
            end
          end
        end
      end
  end
end
