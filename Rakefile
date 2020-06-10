require 'dotenv'
Dotenv.load
require 'active_record'
#require 'resque'
#require 'resque/tasks'
require 'sinatra/activerecord/rake'
require_relative 'update_elliestaging'


namespace :update_elliestaging do
desc 'Set up subs for new charge date this month'
task :setup_elliestaging_subs_new_date do |t|
    FixSubInfo::SubUpdater.new.setup_subs_updating_new_charge_date
end

desc 'fix the missing next_charge_scheduled_at date for subs'
task :fix_next_charge_scheduled_at do |t|
    FixSubInfo::SubUpdater.new.fix_subs_null_next_charge_date
end

desc 'create matching subs prepaid for orders ready to be processed'
task :create_csv_prepaid_subs_from_orders do |t|
    FixSubInfo::SubUpdater.new.create_csv_matching_subs_for_orders
end

desc 'fix testing subs with testing data'
task :fix_testing_subs do |t|
    FixSubInfo::SubUpdater.new.update_testing_sub
end

desc 'fix testing subs to elliepics'
task :fix_testing_subs_to_elliepics do |t|
    FixSubInfo::SubUpdater.new.fix_subs_to_elliepicks
end

desc 'fix orders ellie picks'
task :fix_orders_ellie_picks do |t|
    FixSubInfo::SubUpdater.new.fix_orders_ellie_picks
end

desc 'check allocated ellie picks subs'
task :check_allocated_ellie_picks_subs do |t|
    FixSubInfo::SubUpdater.new.check_allocated_subs

end

desc 'setup prepaid orders for Ellie Picks'
task :setup_prepaid_orders do |t|
    FixSubInfo::SubUpdater.new.setup_prepaid_orders
end

desc 'setup update prepaid config file'
task :update_prepaid_config do |t|
    FixSubInfo::SubUpdater.new.setup_prepaid_config
end

desc 'update prepaid order from config file'
task :update_prepaid_from_config do |t|
    FixSubInfo::SubUpdater.new.update_prepaid_orders

end

desc 'update matching subs from update_prepaid and generate csv'
task :update_matching_subs_prepaid do |t|
    FixSubInfo::SubUpdater.new.update_matching_subs_from_update_prepaid

end

desc 'setup prepaid subs charging this month'
task :setup_prepaid_charging_this_month do |t|
    FixSubInfo::SubUpdater.new.update_prepaid_sub_charging_this_month
end

desc 'load config file for updating prepaid subs charging this month'
task :load_prepaid_sub_config do |t|
    FixSubInfo::SubUpdater.new.load_update_prepaid_subs_config
    
end

desc 'load current products for updating prepaid subs charging tomorrow'
task :load_prepaid_sub_current_prods do |t|
    FixSubInfo::SubUpdater.new.load_current_products
end

desc 'update prepaid charging tomorrow'
task :update_prepaid_charging_tomorrow do |t|
    FixSubInfo::SubUpdater.new.update_prepaid_charging_tomorrow
end

desc 'validate allocation prepaid subs no order'
task :validate_allocation_prepaid_sub_no_order do |t|
    FixSubInfo::SubUpdater.new.subs_no_queued_orders
end

desc 'validate monthly subs allocation'
task :validate_monthly_subs do |t|
    FixSubInfo::SubUpdater.new.validate_monthly_subs
end

desc 'validate prepaid orders'
task :validate_prepaid_orders do |t|
    FixSubInfo::SubUpdater.new.validate_prepaid_orders
end

desc 'validate parent subs for prepaid orders'
task :validate_parent_subs do |t|
    FixSubInfo::SubUpdater.new.validate_parent_subs
end



end