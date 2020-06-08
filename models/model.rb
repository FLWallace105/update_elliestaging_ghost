class SubscriptionsUpdated < ActiveRecord::Base
    self.table_name = "subscriptions_updated"
  end
  
  class CurrentProduct < ActiveRecord::Base
  end
  
  class UpdateProduct < ActiveRecord::Base
  end
  
  class BadMonthlyBox < ActiveRecord::Base
    self.table_name = "bad_monthly_box"
  end
  
  class Customer < ActiveRecord::Base
    self.table_name = 'customers'
  end
  
  class Order < ActiveRecord::Base
    self.primary_key = :order_id
    self.inheritance_column = nil
    has_one :line_items_fixed, class_name: 'OrderLineItemsFixed'
    # has_one :subscription, through: :line_items
  
    def subscription_id
      line_items_fixed.subscription_id
    end
  
    def shopify_product_id
      line_items_fixed.shopify_product_id
    end
  end
  
  class Subscription < ActiveRecord::Base
    self.primary_key = :subscription_id
    has_many :order_line_items, class_name: 'OrderLineItemsFixed'
    has_many :orders, through: :order_line_items
    after_save :update_line_items
  end
  
  class OrderLineItemsFixed < ActiveRecord::Base
    self.table_name = 'order_line_items_fixed'
    belongs_to :subscription
    belongs_to :order
  end
  
  
  class FixThreeMonths < ActiveRecord::Base
    self.table_name = 'fix_three_months'
  end   
  
  class BadRecurringSub < ActiveRecord::Base
    self.table_name = 'bad_recurring_subs'
  end
  
  class ToughLuxeSub < ActiveRecord::Base
    self.table_name = 'tough_luxe_subs'
  end
  
  class Subscription < ActiveRecord::Base
    self.table_name = 'subscriptions'
  end
  
  class SubCollectionSizes < ActiveRecord::Base
    self.table_name = 'sub_collection_sizes'
  end
  
  class SubsUpdatedInventorySize < ActiveRecord::Base
    self.table_name = 'subs_updated_inventory_sizes'
  end

  class UpdatePrepaidOrder < ActiveRecord::Base
    self.table_name = "update_prepaid"
  end

  class UpdatePrepaidConfig < ActiveRecord::Base
    self.table_name =  "update_prepaid_config"
  end