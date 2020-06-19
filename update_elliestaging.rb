#update_subs.rb
require 'dotenv'
Dotenv.load
require 'httparty'
#require 'resque'
#require 'sinatra'
require 'active_record'
require "sinatra/activerecord"
require_relative 'models/model'
#require_relative 'resque_helper'
#require 'pry'

module FixSubInfo
  class SubUpdater
    def initialize
      Dotenv.load
      recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
      @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
      @my_header = {
        "X-Recharge-Access-Token" => recharge_regular
      }
      @my_change_header = {
        "X-Recharge-Access-Token" => recharge_regular,
        "Accept" => "application/json",
        "Content-Type" =>"application/json"
      }
      
    end


    def list_webhooks
        #GET /webhooks

        my_webhooks = HTTParty.get("https://api.rechargeapps.com/webhooks", :headers => @my_header,  :timeout => 80)
        puts my_webhooks.inspect
        temp_webhooks = my_webhooks.parsed_response['webhooks']
        temp_webhooks.each do |myw|
            puts myw
        end

    end

    def update_customers_with_new_token
        #update customers with new token all those migrated
        puts "Setting up customers for updating payment token"
        update_token_customers = "insert into update_token_customers (customer_id, customer_hash, shopify_customer_id, email, created_at, updated_at, first_name, last_name, billing_address1, billing_address2, billing_zip, billing_province, billing_country, billing_phone, processor_type, status ) select customer_id, customer_hash, shopify_customer_id, email, created_at, updated_at, first_name, last_name, billing_address1, billing_address2, billing_zip, billing_province, billing_country, billing_phone, processor_type, status from customers where  (DATE(created_at) = \'2019-05-14\'  or DATE(created_at) = \'2019-05-15\' or DATE(created_at) = \'2019-05-16\' )"
        UpdateTokenCustomers.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('update_token_customers')
        ActiveRecord::Base.connection.execute(update_token_customers)
        puts "All done setting up customers to have their payment token updated"






    end

    def update_customers_token
        my_now = Time.now
        my_customers = UpdateTokenCustomers.where("updated = ?", false) 
        my_customers.each do |my_cust|
            puts my_cust.inspect  
            #fix
            #PUT /customers/<customer_id>
            my_body = {"stripe_customer_token": "cus_HUR1JwpJm7kJms"}.to_json
            customer = HTTParty.put("https://api.rechargeapps.com/customers/#{my_cust.customer_id}", :headers => @my_change_header, :body => my_body, :timeout => 80)
            puts customer.inspect 
            if customer.code == 200
                my_cust.updated = true
                time_updated = DateTime.now
                time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
                my_cust.token_updated = time_updated_str
                my_cust.save
                puts "Updated customer id #{my_cust.customer_id}"

            else
                puts "Could not update customer id #{my_cust.customer_id} with new payment token"

            end

            my_current = Time.now
            duration = (my_current - my_now).ceil
            puts "Been running #{duration} seconds"
            if duration > 480
                puts "Been running more than 8 minutes must exit"
                break
            end


            

            
        end
        puts "Done with this session of updating Customers."
    
    end




    def setup_subs_updating_new_charge_date
        puts "Starting setup"

        elliestaging_nulls = "insert into subscriptions_updated (subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_items) select subscription_id, customer_id, updated_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_item_properties from subscriptions where status = 'ACTIVE' and next_charge_scheduled_at is null   "

        SubscriptionsUpdated.delete_all
        #Now reset index
        ActiveRecord::Base.connection.reset_pk_sequence!('subscriptions_updated')
        ActiveRecord::Base.connection.execute(elliestaging_nulls)

        puts "All done setting up nulls for next_charge_scheduled_at"


    end

    def generate_random_index(mystart, myend)
        return_length = rand(mystart..myend)
        return return_length
        

    end


    def determine_limits(recharge_header, limit)
        puts "recharge_header = #{recharge_header}"
        my_numbers = recharge_header.split("/")
        my_numerator = my_numbers[0].to_f
        my_denominator = my_numbers[1].to_f
        my_limits = (my_numerator/ my_denominator)
        puts "We are using #{my_limits} % of our API calls"
        if my_limits > limit
            puts "Sleeping 15 seconds"
            sleep 15
        else
            puts "not sleeping at all"
        end
    
    end


    def fix_subs_null_next_charge_date

        subs_to_update = SubscriptionsUpdated.where("updated = ?", false)

        subs_to_update.each do |mysub|

        today_date = Date.today + 1
        today_date_day_of_month = today_date.strftime("%e")
        my_end_month_day_of_month = Date.today.end_of_month.strftime("%e")
        puts today_date_day_of_month
        puts my_end_month_day_of_month
        my_day = generate_random_index(today_date_day_of_month.to_i, my_end_month_day_of_month.to_i)
        if my_day < 10
            my_day = "0#{my_day}"
        else
            my_day = "#{my_day}"
        end
        puts "Day of month to be assigned = #{my_day}"
        my_full_month = today_date.strftime("%Y-%m-") + my_day
        puts my_full_month

        #POST /subscriptions/<subscription_id>/set_next_charge_date
        #request.body = { "date":"2018-12-16"}.to_json
        body = { "date" => my_full_month}.to_json

        my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mysub.subscription_id}/set_next_charge_date", :headers => @my_change_header, :body => body, :timeout => 80)
        puts my_update_sub.inspect

        recharge_header = my_update_sub.response["x-recharge-limit"]
        determine_limits(recharge_header, 0.65)

        if my_update_sub.code == 200
            # set update flag and print success
            #Adjust inventory only here
            #adjust_inventory(sub)
  
  
            mysub.updated = true
            time_updated = DateTime.now
            time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
            mysub.processed_at = time_updated_str
            mysub.save!
            puts "Updated subscription id #{mysub.subscription_id}"

        else
            puts "Cound not process subscription_id = #{mysub.subscription_id}"
        end



        end

        puts "All done processing subs"


    end


    def create_csv_matching_subs_for_orders
        puts "Starting CSV matching subs for orders"

        File.delete('elliestaging_order_subs.csv') if File.exist?('elliestaging_order_subs.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "address_id", "customer_id", "created_at", "updated_at", "next_charge_scheduled_at", "price", "status", "title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties"]

        CSV.open('elliestaging_order_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        CSV.foreach('ghost_allocation_test_orders_6_9.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            puts row.inspect
            puts row['customer_id']
            my_customer_id = row['customer_id']
            my_sub = Subscription.where("customer_id = ?", my_customer_id).first
            if !my_sub.nil?
                puts my_sub.inspect

                csv_data_out = [my_sub.subscription_id, my_sub.address_id, my_sub.customer_id, my_sub.created_at, my_sub.updated_at, my_sub.next_charge_scheduled_at, my_sub.price, my_sub.status, my_sub.product_title, my_sub.shopify_product_id, my_sub.shopify_variant_id, my_sub.sku, my_sub.raw_line_item_properties  ]
                hdr << csv_data_out
            else
                puts "No matching sub for the order"
            end
            

        end

    end
    #end of csv part

    end

    def update_testing_sub
        #update_elliestaging.rb
        CSV.foreach('ghost_allocation_testing_6_5.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            #puts row.inspect
            subscription_id = row['subscription_id']
            puts subscription_id

            body = { "date" => "2020-06-05T23:59:59.999999"}.to_json

            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{subscription_id}/set_next_charge_date", :headers => @my_change_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect
            
        end


    end

    def fix_subs_to_elliepicks
        new_sub_properties2 = { "sku" => "79999999", "product_title" => "Ellie Picks - 2 Items", "shopify_product_id" => 4575733743755, "shopify_variant_id" => 32444735389835, "properties" => [] }

        new_sub_properties3 = { "sku" => "79999998", "product_title" => "Ellie Picks - 3 Items", "shopify_product_id" => 4575735087243, "shopify_variant_id" => 32444760555659, "properties" => [] }

        new_sub_properties5 = { "sku" => "79999997", "product_title" => "Ellie Picks - 5 Items", "shopify_product_id" => 4575735382155, "shopify_variant_id" => 32444765667467, "properties" => [] }

        blank_sub = Hash.new

        CSV.foreach('ghost_allocation_testing_6_5.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            #puts row.inspect
            subscription_id = row['subscription_id']
            puts subscription_id
            my_sub = Subscription.find_by_subscription_id(subscription_id)
            #puts my_sub.inspect
            puts my_sub.product_title
            temp_product_title = my_sub.product_title
            sub_properties = Hash.new
            product_collection = ""
            case temp_product_title
                when /\s2\sitem/i
                    puts "two item"
                    sub_properties = new_sub_properties2
                    product_collection = "Ellie Picks - 2 Items"
                when /\s3\sitem/i
                    puts "three item"
                    sub_properties = new_sub_properties3
                    product_collection = "Ellie Picks - 3 Items"
                when /\s5\sitem/i
                    puts "five item"
                    sub_properties = new_sub_properties5
                    product_collection = "Ellie Picks - 5 Items"
                else
                    puts "cannot find item"
                    sub_properties = blank_sub
                end
            
            temp_properties = my_sub.raw_line_item_properties
            
            temp_properties.map do |mystuff|
                # puts "#{key}, #{value}"
                if mystuff['name'] == 'product_collection'
                  mystuff['value'] = product_collection
                  
                end
            end

            sub_properties['properties'] = temp_properties
            puts sub_properties.inspect

            body = sub_properties.to_json

            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect
            recharge_header = my_update_sub.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)

            

        end

        puts "All done updating test subs for Ellie Picks"

    end

    def fix_orders_ellie_picks
        puts "Starting to fix orders Ellie Picks"
        #ghost_allocation_test_orders_6_5.csv
        #\copy (select orders.order_id, orders.scheduled_at, orders.customer_id, order_line_items_fixed.title, order_line_items_fixed.shopify_product_id, order_line_items_fixed.shopify_variant_id, orders.first_name, orders.last_name, orders.email, orders.line_items from orders, order_line_items_fixed  where order_line_items_fixed.order_id = orders.order_id and orders.scheduled_at > '2020-06-08' and orders.scheduled_at < '2020-06-10' and orders.is_prepaid = 1) to 'ghost_allocation_test_orders_6_9.csv' CSV HEADER;


        CSV.foreach('ghost_allocation_test_orders_6_9.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            #puts row.inspect
            my_order_id = row['order_id']
            my_order = Order.find_by_order_id(my_order_id)
            puts my_order.inspect
            
            my_props = my_order.line_items.first['properties']
            puts my_props.inspect
            my_props.map do |myp|
                if myp['name'] == 'product_collection'
                    #myp['value'] = "Funky!!!!!"
                    temp_collection = myp['value']
                    product_collection = ""
                    case temp_collection
                    when /\s2\sitem/i
                        puts "two item"
                        product_collection = "Ellie Picks - 2 Items"
                    when /\s3\sitem/i
                        puts "three item"
                        product_collection = "Ellie Picks - 3 Items"
                    when /\s5\sitem/i
                        puts "five item"
                        product_collection = "Ellie Picks - 5 Items"
                    else
                        puts "cannot find item"
                        product_collection = ""
                    end
                    myp['value'] = product_collection
                    
                  end

            end
            puts my_props.inspect

            fixed_order = my_order.line_items
            #Add Recharge required stuff
            
            #remove shopify_variant_id:
            
            fixed_order[0].tap {|myh| myh.delete('shopify_variant_id')}
            fixed_order[0].tap {|myh| myh.delete('shopify_product_id')}
            fixed_order[0].tap {|myh| myh.delete('images')}

            fixed_order[0]['properties'] = my_props

            puts fixed_order.inspect

            my_data = { "line_items" => fixed_order }

            my_update_order = HTTParty.put("https://api.rechargeapps.com/orders/#{my_order_id}", :headers => @my_change_header, :body => my_data.to_json, :timeout => 80)
            puts my_update_order.inspect
            recharge_header = my_update_order.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)


        end


    end

    def check_allocated_subs

        File.delete('checked_subscriptions.csv') if File.exist?('checked_subscriptions.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "product_title", "product_collection", "properties"]

    CSV.open('checked_subscriptions.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        CSV.foreach('testing_monthly_subs_6_9.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            #puts row.inspect
            subscription_id = row['subscription_id']
            puts subscription_id
            #GET /subscriptions/<subscription_id>
            temp_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header,  :timeout => 80)
            puts temp_sub_info.inspect
            puts temp_sub_info.parsed_response['subscription'].inspect
            puts temp_sub_info.parsed_response['subscription']['product_title']
            my_props = temp_sub_info.parsed_response['subscription']['properties']
            my_prod_collection = my_props.select {|x| x['name'] == 'product_collection' }
            product_collection = my_prod_collection.first['value']
            puts product_collection
            csv_data_out = [subscription_id, temp_sub_info.parsed_response['subscription']['product_title'], product_collection, my_props  ]
            hdr << csv_data_out
            
            
        end
        #csv out
    end

    end

    def setup_prepaid_orders
        puts "Starting set up"
        update_elliestaging_prepaid_sql = "insert into update_prepaid (order_id, transaction_id, charge_status, payment_processor, address_is_active, status, order_type, charge_id, address_id, shopify_id, shopify_order_id, shopify_cart_token, shipping_date, scheduled_at, shipped_date, processed_at, customer_id, first_name, last_name, is_prepaid, created_at, updated_at, email, line_items, total_price, shipping_address, billing_address, synced_at) select order_id, transaction_id, charge_status, payment_processor, address_is_active, status, order_type, charge_id, address_id, shopify_id, shopify_order_id, shopify_cart_token, shipping_date, scheduled_at, shipped_date, processed_at, customer_id, first_name, last_name, is_prepaid, created_at, updated_at, email, line_items, total_price, shipping_address, billing_address, synced_at from orders where is_prepaid = \'1\'  and scheduled_at > \'2020-06-08\' and scheduled_at < \'2020-06-10\' and status = \'QUEUED\' "

        UpdatePrepaidOrder.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('update_prepaid')
        ActiveRecord::Base.connection.execute(update_elliestaging_prepaid_sql)
        puts "Done set up"



    end

    def setup_prepaid_config
        UpdatePrepaidConfig.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('update_prepaid_config')
        CSV.foreach('elliestaging_update_prepaid_config.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect
           title = row['title']
           product_id = row['product_id']
           variant_id = row['variant_id']
           product_collection = row['product_collection']
           UpdatePrepaidConfig.create(title: title, product_id: product_id, variant_id: variant_id, product_collection: product_collection)
           
         end

    end


    def update_prepaid_orders
        my_update_orders = UpdatePrepaidOrder.where(is_updated: false)
        my_update_orders.each do |myorder|
            my_title = myorder.line_items[0]['title']
            config_data = UpdatePrepaidConfig.find_by_title(my_title)
            #puts config_data.inspect
            my_product_collection = config_data.product_collection
            #puts my_product_collection.inspect
            my_line_items = myorder.line_items[0]['properties']

            my_line_items.map do |mystuff|
                if mystuff['name'] == 'product_collection'
                    mystuff['value'] = my_product_collection
                end
            end

            fixed_order = Array.new
            fixed_order = myorder.line_items

            #Add Recharge required stuff
            fixed_order[0]['product_id'] = config_data.product_id.to_i
            fixed_order[0]['variant_id'] = config_data.variant_id.to_i
            fixed_order[0]['quantity'] = 1
            fixed_order[0]['title'] = config_data.title


            fixed_order[0].tap {|myh| myh.delete('shopify_variant_id')}
            fixed_order[0].tap {|myh| myh.delete('shopify_product_id')}
            fixed_order[0].tap {|myh| myh.delete('images')}

            my_data = { "line_items" => fixed_order }


            puts "Now here is what we are sending to Recharge"
            puts my_data.inspect
            my_update_order = HTTParty.put("https://api.rechargeapps.com/orders/#{myorder.order_id}", :headers => @my_change_header, :body => my_data.to_json, :timeout => 80)
            puts my_update_order.inspect
            recharge_header = my_update_order.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)

            if my_update_order.code == 200
                myorder.is_updated = true
                time_updated = DateTime.now
                time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
                myorder.updated_at = time_updated_str
                myorder.save

            else
                puts "WE could not update the order order_id = #{myorder.order_id}"

            end


        end

        puts "All done updating prepaid orders"

    end

    def update_matching_subs_from_update_prepaid

        puts "Starting CSV matching subs for orders"

        File.delete('elliestaging_prepaid_order_subs.csv') if File.exist?('elliestaging_prepaid_order_subs.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "address_id", "customer_id", "created_at", "updated_at", "next_charge_scheduled_at", "price", "status", "product_title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties"]

        CSV.open('elliestaging_prepaid_order_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        #find with sql
        my_target_subs = "select subscriptions.subscription_id, subscriptions.product_title from subscriptions, update_prepaid, order_line_items_fixed where subscriptions.subscription_id = order_line_items_fixed.subscription_id and order_line_items_fixed.order_id = update_prepaid.order_id"
        my_subs = ActiveRecord::Base.connection.execute(my_target_subs)
        my_subs.each do |mys|
            puts mys.inspect

            full_sub = Subscription.find_by_subscription_id(mys['subscription_id'])
            puts full_sub.inspect
            my_product_collection = UpdatePrepaidConfig.find_by_product_id(full_sub.shopify_product_id)
            puts my_product_collection.product_collection

            temp_line_items = full_sub.raw_line_item_properties

            temp_line_items.map do |mystuff|
                # puts "#{key}, #{value}"
                if mystuff['name'] == 'product_collection'
                    mystuff['value'] = my_product_collection.product_collection
                    
                end
            end
            puts "Send to Recharge properties: #{temp_line_items}"
            send_to_recharge = { "properties" => temp_line_items }

            body = send_to_recharge.to_json

            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{full_sub.subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect
            recharge_header = my_update_sub.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)

            csv_data_out = [full_sub.subscription_id, full_sub.address_id, full_sub.customer_id, full_sub.created_at, full_sub.updated_at, full_sub.next_charge_scheduled_at, full_sub.price, full_sub.status, full_sub.product_title, full_sub.shopify_product_id, full_sub.shopify_variant_id, full_sub.sku, temp_line_items  ]
            hdr << csv_data_out



        end

        end
        #end of csv part



    end

    def update_prepaid_sub_charging_this_month
        puts "setting up prepaid subs charging this month"

        june2020_ellie_picks = "insert into subscriptions_updated (subscription_id, customer_id, updated_at, created_at,  next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_items) select subscription_id, customer_id, updated_at, created_at, next_charge_scheduled_at, product_title, status, sku, shopify_product_id, shopify_variant_id, raw_line_item_properties from subscriptions where status = 'ACTIVE' and next_charge_scheduled_at > '2020-06-08'  and  next_charge_scheduled_at < '2020-06-10'  and product_title  ilike \'3%month%\'  "

        SubscriptionsUpdated.delete_all
        #Now reset index
        ActiveRecord::Base.connection.reset_pk_sequence!('subscriptions_updated')
        ActiveRecord::Base.connection.execute(june2020_ellie_picks)


    end

    def load_update_prepaid_subs_config
        puts "loading config information to update prepaid subs charging this month"
        UpdateProduct.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('update_products')
        CSV.foreach('update_products_ellie_picks.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect
           sku = row['sku']
           product_title = row['product_title']
           shopify_product_id = row['shopify_product_id']
           shopify_variant_id = row['shopify_variant_id']
           product_collection = row['product_collection']
           UpdateProduct.create(sku: sku, product_title: product_title, shopify_product_id: shopify_product_id, shopify_variant_id: shopify_variant_id, product_collection: product_collection)
        end
        puts "All done loading configuration for updating prepaid subs"

    end


    
  
    def load_current_products
        CurrentProduct.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('current_products')
        puts "I am here"
  
        
        CSV.foreach('prepaid_subs_current.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
           puts row.inspect
          prod_id_key = row['prod_id_key']
          prod_id_value = row['prod_id_value']
          next_month_prod_id = row['next_month_prod_id']
          prepaid = row['prepaid']
          CurrentProduct.create(prod_id_key: prod_id_key, prod_id_value: prod_id_value, next_month_prod_id: next_month_prod_id, prepaid: prepaid)
        end
        
    end

    def update_prepaid_charging_tomorrow
        puts "Starting update prepaid charging tomorrow"

        puts "Starting CSV matching subs for orders"

        File.delete('elliestaging_prepaid_sub_charge_tomorrow.csv') if File.exist?('elliestaging_prepaid_sub_charge_tomorrow.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "customer_id", "updated_at", "next_charge_scheduled_at", "status", "product_title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties"]

        CSV.open('elliestaging_prepaid_sub_charge_tomorrow.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        mysubs = SubscriptionsUpdated.where("updated = ?", false)
        mysubs.each do |mysub|
            my_product_id = mysub.shopify_product_id
            next_month_product = CurrentProduct.find_by_prod_id_value(my_product_id)
            next_month_product_id = next_month_product.next_month_prod_id
            my_product_collection = UpdateProduct.find_by_shopify_product_id(next_month_product_id)
            my_product_collection_title = my_product_collection.product_collection

            temp_line_items = mysub.raw_line_items

            temp_line_items.map do |mystuff|
                # puts "#{key}, #{value}"
                if mystuff['name'] == 'product_collection'
                    mystuff['value'] = my_product_collection_title
                    
                end
            end
            puts "Send to Recharge properties: #{temp_line_items}"
            send_to_recharge = { "properties" => temp_line_items }

            body = send_to_recharge.to_json

            my_update_sub = HTTParty.put("https://api.rechargeapps.com/subscriptions/#{mysub.subscription_id}", :headers => @my_change_header, :body => body, :timeout => 80)
            puts my_update_sub.inspect
            recharge_header = my_update_sub.response["x-recharge-limit"]
            determine_limits(recharge_header, 0.65)

            if my_update_sub.code == 200

                csv_data_out = [mysub.subscription_id, mysub.customer_id,  mysub.updated_at, mysub.next_charge_scheduled_at, mysub.status, mysub.product_title, mysub.shopify_product_id, mysub.shopify_variant_id, mysub.sku, temp_line_items  ]
                hdr << csv_data_out
                
      
                mysub.updated = true
                time_updated = DateTime.now
                time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
                mysub.processed_at = time_updated_str
                mysub.save!
                puts "Updated subscription id #{mysub.subscription_id}"
    
            else
                puts "Cound not process subscription_id = #{mysub.subscription_id}"
            end


        end

        end
        #CSV output


    end

    def subs_no_queued_orders
        "Starting processing subs no queued orders"

        File.delete('validation_prepaid_sub_no_order.csv') if File.exist?('validation_prepaid_sub_no_order.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "customer_id", "updated_at", "next_charge_scheduled_at", "status", "product_title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties", "new_title", "new_product_id", "new_variant_id", "new_sku", "product_collection", "new_properties"]

        CSV.open('validation_prepaid_sub_no_order.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        CSV.foreach('elliestaging_prepaid_sub_charge_tomorrow.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect
            subscription_id = row['susbcription_id']
            customer_id = row['customer_id']
            updated_at = row['updated_at']
            next_charge_scheduled_at = row['next_charge_scheduled_at']
            status = row['status']
            product_title = row['product_title']
            shopify_product_id = row['shopify_product_id']
            shopify_variant_id = row['shopify_variant_id']
            mysku = row['sku']
            raw_line_item_properties = row['raw_line_item_properties']
            puts "----"
            puts subscription_id

            temp_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header,  :timeout => 80)
            puts temp_sub_info.inspect
            puts temp_sub_info.parsed_response['subscription'].inspect
            puts temp_sub_info.parsed_response['subscription']['product_title']
            product_title = temp_sub_info.parsed_response['subscription']['product_title']
            product_id = temp_sub_info.parsed_response['subscription']['shopify_product_id']
            variant_id = temp_sub_info.parsed_response['subscription']['shopify_variant_id']
            sku = temp_sub_info.parsed_response['subscription']['sku']
            my_props = temp_sub_info.parsed_response['subscription']['properties']
            my_prod_collection = my_props.select {|x| x['name'] == 'product_collection' }
            product_collection = my_prod_collection.first['value']
            puts product_collection

            csv_data_out = [subscription_id, customer_id, updated_at, next_charge_scheduled_at, status, product_title, shopify_product_id, shopify_variant_id, mysku, raw_line_item_properties, product_title, product_id, variant_id, sku, product_collection, my_props  ]
            hdr << csv_data_out

        end

    end

    end
    #csv part

    def validate_monthly_subs
        puts "Starting validation monthly subs"

        File.delete('validation_monthly_subs.csv') if File.exist?('validation_monthly_subs.csv')

        #Headers for CSV
        column_header = ["susbcription_id", "address_id", "customer_id", "created_at", "updated_at", "next_charge_scheduled_at", "price", "status", "product_title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties", "new_title", "new_product_id", "new_variant_id", "new_sku", "product_collection", "new_properties"]

        CSV.open('validation_monthly_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil


        CSV.foreach('testing_monthly_subs_6_9.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect
            
            subscription_id = row['subscription_id']
            address_id = row['address_id']
            customer_id = row['customer_id']
            created_at = row['created_at']
            updated_at = row['updated_at']
            next_charge_scheduled_at = row['next_charge_scheduled_at']
            my_product_title = row['product_title']
            price = row['price']
            status = row['status']
            shopify_product_id = row['shopify_product_id']
            shopify_variant_id = row['shopify_variant_id']
            mysku = row['sku']
            raw_line_item_properties = row['raw_line_item_properties']

            puts "----"
            puts subscription_id

            temp_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header,  :timeout => 80)
            puts temp_sub_info.inspect
            if temp_sub_info.parsed_response['errors'] == "Not Found"
                csv_data_out = [subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, price, status, my_product_title, shopify_product_id, shopify_variant_id, mysku, raw_line_item_properties, "Not Found", "Not Found", "Not Found", "Not Found", "Not Found", "Not Found"  ]
                hdr << csv_data_out
            else
            puts temp_sub_info.parsed_response['subscription'].inspect
            puts temp_sub_info.parsed_response['subscription']['product_title']
            
            product_title = temp_sub_info.parsed_response['subscription']['product_title']
            product_id = temp_sub_info.parsed_response['subscription']['shopify_product_id']
            variant_id = temp_sub_info.parsed_response['subscription']['shopify_variant_id']
            sku = temp_sub_info.parsed_response['subscription']['sku']
            my_props = temp_sub_info.parsed_response['subscription']['properties']
            my_prod_collection = my_props.select {|x| x['name'] == 'product_collection' }
            product_collection = ""
            if my_prod_collection == []
                product_collection = ""
            else
                product_collection = my_prod_collection.first['value']
                puts product_collection
            end
            

            csv_data_out = [subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, price, status, my_product_title, shopify_product_id, shopify_variant_id, mysku, raw_line_item_properties, product_title, product_id, variant_id, sku, product_collection, my_props  ]
            hdr << csv_data_out
            end



        end

        end
        #end csv


    end


    def validate_prepaid_orders
        puts "Starting validation of prepaid orders"

        File.delete('validation_prepaid_orders.csv') if File.exist?('validation_prepaid_orders.csv')

        #Headers for CSV
        column_header = ["order_id", "scheduled_at", "customer_id", "title", "shopify_product_id", "shopify_variant_id", "first_name", "last_name", "email", "old_line_items", "new_product_title", "new_shopify_product_id", "new_shopify_variant_id",  "new_sku", "subscription_id", "new_product_collection", "subscription_product_collection", "match", "new_properties"]

        CSV.open('validation_prepaid_orders.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil


        CSV.foreach('ghost_allocation_test_orders_6_9_changed.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect

            puts "------"

            order_id = row['order_id']
            scheduled_at = row['scheduled_at']
            customer_id = row['customer_id']
            title = row['title']
            shopify_product_id = row['shopify_product_id']
            shopify_variant_id = row['shopify_variant_id']
            first_name = row['first_name']
            last_name = row['last_name']
            email = row['email']
            line_items = row['line_items']

            #GET /orders/<order_id>
            temp_order_info = HTTParty.get("https://api.rechargeapps.com/orders/#{order_id}", :headers => @my_header,  :timeout => 80)

            puts temp_order_info.inspect
            order_info = temp_order_info.parsed_response['order']
            puts order_info.inspect
            new_product_title = order_info['line_items'].first.dig('product_title')
            
            new_shopify_product_id = order_info['line_items'].first.dig('shopify_product_id')
            new_shopify_variant_id = order_info['line_items'].first.dig('shopify_variant_id')
            new_sku = order_info['line_items'].first.dig('sku')
            product_collection_array = order_info['line_items'].first.dig('properties')
            subscription_id = order_info['line_items'].first.dig('subscription_id')
            puts new_product_title
            puts new_shopify_product_id
            puts new_shopify_variant_id
            product_collection_hash = product_collection_array.select { |x| x['name'] == 'product_collection' }
            product_collection = product_collection_hash.first['value']
            puts product_collection

            temp_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header,  :timeout => 80)

            my_props = temp_sub_info.parsed_response['subscription']['properties']
            my_prod_collection = my_props.select {|x| x['name'] == 'product_collection' }
            sub_product_collection = my_prod_collection.first['value']
            match = ( product_collection == sub_product_collection ? true : false )



            csv_data_out = [order_id, scheduled_at, customer_id, title, shopify_product_id, shopify_variant_id, first_name, last_name, email, line_items, new_product_title, new_shopify_product_id, new_shopify_variant_id, new_sku, subscription_id, product_collection, sub_product_collection, match, product_collection_array  ]
            hdr << csv_data_out


        end


    end
    end
    #CSV out

    def validate_parent_subs
        puts "Validating parent subs to prepaid orders"

        File.delete('validation_parent_subs.csv') if File.exist?('validation_parent_subs.csv')

        #Headers for CSV
        column_header = ["subscription_id", "address_id", "customer_id", "created_at", "updated_at", "next_charge_scheduled_at", "price", "status", "title", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties",  "new_product_tile", "new_product_id", "new_variant_id", "new_sku", "old_product_collection", "new_product_collection", "new_properties"]

        CSV.open('validation_parent_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        CSV.foreach('elliestaging_order_subs.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
            puts row.inspect
            puts "-----------"
            subscription_id = row['susbcription_id']
            address_id = row['address_id']
            customer_id = row['customer_id']
            created_at = row['created_at']
            updated_at = row['updated_at']
            next_charge_scheduled_at = row['next_charge_scheduled_at']
            price = row['price']
            status = row['status']
            title = row['title']
            shopify_product_id = row['shopify_product_id']
            shopify_variant_id = row['shopify_variant_id']
            sku = row['sku']
            raw_line_item_properties = row['raw_line_item_properties']

            properties_to_array = eval(raw_line_item_properties)
            puts properties_to_array.inspect
            old_product_collection = properties_to_array.select { |x| x['name'] == 'product_collection'}
            puts "--------------"
            puts old_product_collection.inspect
            my_old_product_collection = old_product_collection.first['value']
            puts "-------------"


            temp_sub_info = HTTParty.get("https://api.rechargeapps.com/subscriptions/#{subscription_id}", :headers => @my_header,  :timeout => 80)

            puts temp_sub_info.inspect

            puts temp_sub_info.parsed_response['subscription'].inspect
            puts temp_sub_info.parsed_response['subscription'].dig('product_title')
            
            new_product_title = temp_sub_info.parsed_response['subscription'].dig('product_title')
            new_product_id = temp_sub_info.parsed_response['subscription'].dig('shopify_product_id')
            new_variant_id = temp_sub_info.parsed_response['subscription'].dig('shopify_variant_id')
            new_sku = temp_sub_info.parsed_response['subscription'].dig('sku')
            my_props = temp_sub_info.parsed_response['subscription']['properties']
            my_prod_collection = my_props.select {|x| x['name'] == 'product_collection' }
            new_product_collection = my_prod_collection.first['value']

            csv_data_out = [subscription_id, address_id, customer_id, created_at, updated_at, next_charge_scheduled_at, price, status, title, shopify_product_id, shopify_variant_id, sku, raw_line_item_properties, new_product_title, new_product_id, new_variant_id, new_sku, my_old_product_collection, new_product_collection, my_prod_collection  ]
            hdr << csv_data_out


        end
        end
        #end of CSV


    end



end
end