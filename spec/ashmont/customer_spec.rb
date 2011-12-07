require 'spec_helper'
require 'ashmont/customer'

describe Ashmont::Customer do
  it "has returns its first credit card" do
    token = "xyz"
    remote_customer = stub("customer", :credit_cards => ["first", "second"])
    Braintree::Customer.stubs(:find => remote_customer)

    result = Ashmont::Customer.new(token).credit_card

    Braintree::Customer.should have_received(:find).with(token)
    result.should == "first"
  end

  it "returns nothing without a remote customer" do
    Ashmont::Customer.new.credit_card.should be_nil
  end

  it "returns the remote email" do
    remote_customer = stub("customer", :email => "admin@example.com")
    Braintree::Customer.stubs(:find => remote_customer)

    Ashmont::Customer.new("abc").billing_email.should == "admin@example.com"
  end

  it "doesn't have an email without a remote customer" do
    Ashmont::Customer.new.billing_email.should be_nil
  end

  it "creates a valid remote customer" do
    token = "xyz"
    remote_customer = stub("customer", :credit_cards => [], :id => token)
    create_result = stub("result", :success? => true, :customer => remote_customer)
    attributes = { "email" => "ben@example.com" }
    Braintree::Customer.stubs(:create => create_result)

    customer = Ashmont::Customer.new
    customer.save(attributes).should be_true

    Braintree::Customer.should have_received(:create).with(attributes)
    customer.token.should == token
    customer.errors.should be_empty
  end

  it "returns errors while creating an invalid remote customer" do
    error_messages = "error messages"
    errors = "errors"
    verification = "failure"
    create_result = stub("result",
                         :success? => false,
                         :errors => error_messages,
                         :credit_card_verification => verification)
    Braintree::Customer.stubs(:create => create_result)
    Ashmont::Errors.stubs(:new => errors)

    customer = Ashmont::Customer.new
    customer.save("email" => "ben.franklin@example.com").should be_false

    Ashmont::Errors.should have_received(:new).with(verification, error_messages)
    customer.errors.should == errors
  end

  it "updates a remote customer with valid changes" do
    token = "xyz"
    updates = { "email" => 'somebody@example.com' }
    customer = stub("customer", :id => token, :email => "somebody@example.com")
    update_result = stub('result', :success? => true, :customer => customer)
    Braintree::Customer.stubs(:update => update_result)

    customer = Ashmont::Customer.new(token)
    customer.save(updates).should be_true

    Braintree::Customer.should have_received(:update).with(token, updates)
    customer.billing_email.should == "somebody@example.com"
  end

  it "returns errors while updating an invalid customer" do
    error_messages = "error messages"
    errors = "errors"
    verification = "failure"
    update_result = stub("result",
                         :success? => false,
                         :errors => error_messages,
                         :credit_card_verification => verification)
    Braintree::Customer.stubs(:update => update_result)
    Ashmont::Errors.stubs(:new => errors)

    customer = Ashmont::Customer.new("xyz")
    customer.save("email" => "ben.franklin@example.com").should be_false

    Ashmont::Errors.should have_received(:new).with(verification, error_messages)
    customer.errors.should == errors
  end

  it "delete a remote customer" do
    token = "xyz"
    Braintree::Customer.stubs(:delete)

    customer = Ashmont::Customer.new(token)
    customer.delete

    Braintree::Customer.should have_received(:delete).with(token)
  end

  it "has billing info with a credit card" do
    token = "abc"
    credit_card = stub("credit_card", :token => token)
    remote_customer = stub("customer", :credit_cards => [credit_card])
    Braintree::Customer.stubs(:find => remote_customer)

    customer = Ashmont::Customer.new("xyz")
    customer.should have_billing_info
    customer.payment_method_token.should == token
  end

  it "doesn't have billing info without a credit card" do
    remote_customer = stub("customer", :credit_cards => [])
    Braintree::Customer.stubs(:find => remote_customer)

    customer = Ashmont::Customer.new("xyz")
    customer.should_not have_billing_info
    customer.payment_method_token.should be_nil
  end

  %w(last_4 cardholder_name expiration_month expiration_year).each do |credit_card_attribute|
    it "delegates ##{credit_card_attribute} to its credit card" do
      credit_card = stub("credit_card", credit_card_attribute => "expected")
      remote_customer = stub("customer", :credit_cards => [credit_card])
      Braintree::Customer.stubs(:find => remote_customer)

      Ashmont::Customer.new("xyz").send(credit_card_attribute).should == "expected"
    end
  end

  %w(street_address extended_address locality region postal_code country_name).each do |billing_address_attribute|
    it "delegates ##{billing_address_attribute} to its billing address" do
      billing_address = stub("billing_address", billing_address_attribute => "expected")
      credit_card = stub("credit_card", :billing_address => billing_address)
      remote_customer = stub("customer", :credit_cards => [credit_card])
      Braintree::Customer.stubs(:find => remote_customer)

      Ashmont::Customer.new("xyz").send(billing_address_attribute).should == "expected"
    end
  end
end