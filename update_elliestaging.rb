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
        column_header = ["susbcription_id", "address_id", "customer_id", "created_at", "updated_at", "next_charge_scheduled_at", "price", "status", "shopify_product_id", "shopify_variant_id", "sku", "raw_line_item_properties"]

        CSV.open('elliestaging_order_subs.csv','a+', :write_headers=> true, :headers => column_header) do |hdr|
            column_header = nil

        CSV.foreach('ghost_allocation_test_orders_6_5.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
            puts row.inspect
            puts row['customer_id']
            my_customer_id = row['customer_id']
            my_sub = Subscription.where("customer_id = ?", my_customer_id).first
            if !my_sub.nil?
                puts my_sub.inspect

                csv_data_out = [my_sub.subscription_id, my_sub.address_id, my_sub.customer_id, my_sub.created_at, my_sub.updated_at, my_sub.next_charge_scheduled_at, my_sub.status, my_sub.shopify_product_id, my_sub.shopify_variant_id, my_sub.sku, my_sub.raw_line_item_properties  ]
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
        CSV.foreach('ghost_allocation_test_orders_6_5.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
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

        CSV.foreach('ghost_allocation_testing_6_5.csv', :encoding => 'ISO8859-1:utf-8', :headers => true) do |row|
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


end
end