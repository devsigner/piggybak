class RefactorPayments < ActiveRecord::Migration
  def change
    change_table :payment_methods do |t|
      t.remove :klass
      t.string :type, null: false, default: 'Piggybak::PaymentMethods::ActiveMerchantGateway'
      t.string :gateway_klass
    end
    
    change_table :payments do |t|
      t.change_default :status, 'pending'
    end
  end
end
