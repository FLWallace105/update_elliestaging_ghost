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

end