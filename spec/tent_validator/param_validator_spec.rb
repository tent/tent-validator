require 'spec_helper'

describe TentValidator::ParamValidator do
  let(:resources) { [:foo, :bar, :baz] }
  let(:validator_name) { :bar }
  let(:validator_instance) do
    validator = Class.new(described_class)
    validator.class_eval do
      register :bar
    end
    validator.new(:resources => resources)
  end

  let(:other_validator_instance) do
    validator = Class.new(described_class)
    validator.class_eval do
      register :baz
    end
    validator.new(:resources => resources)
  end

  let(:infinity) { 1/0.0 }
  let(:negative_infinity) { -1/0.0 }

  it 'should allow subclasses to register their names' do
    validator = Class.new(described_class)
    validator.class_eval do
      register :foo
    end
    expect(described_class.find(:foo)).to eql(validator)
  end

  it "should know it's registered name" do
    expect(validator_instance.name).to eql(validator_name)
  end

  describe "#resources" do
    it "should return resources option validator initialized with" do
      expect(validator_instance.resources).to eql(resources)
    end
  end

  describe "#response_expectation_options" do
    it "should return memoized value of #generate_response_expectation_options" do
      value = nil
      generate_value = proc { value = rand(10**10) }
      validator_instance.class_eval do
        define_method :generate_response_expectation_options do
          generate_value.call
        end
      end

      expect(validator_instance.response_expectation_options).to_not be_nil
      expect(validator_instance.response_expectation_options).to eql(value)
      expect(validator_instance.response_expectation_options).to eql(validator_instance.response_expectation_options)
    end
  end

  describe "#generate_response_expectation_options" do
    it "should return an empty hash" do
      expect(validator_instance.generate_response_expectation_options).to eql(Hash.new)
    end
  end

  describe "#client_params" do
    it "should return memoized value of #generate_client_params" do
      value = nil
      generate_value = proc { value = rand(10**10) }
      validator_instance.class_eval do
        define_method :generate_client_params do
          generate_value.call
        end
      end

      expect(validator_instance.client_params).to_not be_nil
      expect(validator_instance.client_params).to eql(value)
      expect(validator_instance.client_params).to eql(validator_instance.client_params)
    end
  end

  describe "#generate_client_params" do
    it "should return an empty hash" do
      expect(validator_instance.generate_client_params).to eql(Hash.new)
    end
  end

  describe "#merge" do
    context "with a single other instance as argument" do
      it "should create new instance with merged client_params and response_expectation_options" do
        client_params = {
          :foo => {
            :bar => :baz
          }
        }
        response_expectation_options = {
          :hello => {
            :world => :in_space
          }
        }
        validator_instance.class_eval do
          define_method :generate_client_params do
            client_params
          end

          define_method :generate_response_expectation_options do
            response_expectation_options
          end
        end

        other_client_params = {
          :foo => {
            :blip => :bleep
          }
        }
        other_response_expectation_options = {
          :join => :us,
          :hello => {
            :space => :world
          }
        }
        other_validator_instance.class_eval do
          define_method :generate_client_params do
            other_client_params
          end

          define_method :generate_response_expectation_options do
            other_response_expectation_options
          end
        end

        merged_instance = validator_instance.merge(other_validator_instance)
        expect(merged_instance.client_params).to eql({
          :foo => {
            :bar => :baz,
            :blip => :bleep
          }
        })
        expect(merged_instance.response_expectation_options).to eql({
          :join => :us,
          :hello => {
            :world => :in_space,
            :space => :world
          }
        })
        expect(merged_instance.resources).to eql(resources)
        expect(validator_instance.client_params).to eql(client_params)
        expect(validator_instance.response_expectation_options).to eql(response_expectation_options)
        expect(other_validator_instance.client_params).to eql(other_client_params)
        expect(other_validator_instance.response_expectation_options).to eql(other_response_expectation_options)
      end
    end

    context "with multiple other instances as arguments" do
      it "should create new instance with merged client_params and response_expectation_options" do
        random_hash = proc do
          {
            Faker::Lorem.word => Faker::Lorem.word
          }
        end

        instances = 4.times.map do |n|
          validator = Class.new(described_class)
          validator.class_eval do
            define_method :generate_client_params do
              random_hash.call
            end

            define_method :generate_response_expectation_options do
              random_hash.call
            end
          end
          validator.new(:resources => resources)
        end

        first_instance = instances.first
        merged_instance = first_instance.merge(*instances[1..-1])
        expect(merged_instance.client_params).to eql(instances.inject({}) { |m, i| m.merge(i.client_params) })
        expect(merged_instance.response_expectation_options).to eql(instances.inject({}) { |m, i| m.merge(i.response_expectation_options) })
      end
    end

    context "when validators have merge hooks" do
      it "should call matching merge hooks" do
        plentiful_validator = Class.new(described_class)
        plentiful_validator.class_eval do
          register :plentiful

          with :water, :not => :fire do |i|
            i.client_params[:chemicals] = [:hydrogen, :oxygen]
            i.response_expectation_options[:quantity] = (1/0.0) # Infinity
          end

          with :water, :fire do |i|
            i.client_params[:heat] = :hot
            i.response_expectation_options[:quantity] = (-1/0.0) # -Infinity
          end

          with :fire, :not => :water do |i|
            i.client_params[:reaction] = :combustion
            i.response_expectation_options[:body] = :hot_light
          end
        end

        water_validator = Class.new(described_class)
        water_validator.class_eval do
          register :water

          with :plentiful do |i|
            i.client_params[:ocean] = true
            i.response_expectation_options[:salty] = true
          end
        end

        fire_validator = Class.new(described_class)
        fire_validator.class_eval do
          register :fire

          with :water do |i|
            i.client_params[:smoke] = true
          end

          with :plentiful, :not => :water do |i|
            i.client_params[:height] = (1/0.0) # Infinity
          end
        end

        plentiful_instance = plentiful_validator.new({})
        water_instance = water_validator.new({})
        fire_instance = fire_validator.new({})

        plentiful_water = plentiful_instance.merge(water_instance)
        plentiful_fire = plentiful_instance.merge(fire_instance)
        plentiful_fire_water = plentiful_instance.merge(fire_instance, water_instance)
        water_fire = water_instance.merge(fire_instance)
        fire_water = fire_instance.merge(water_instance)

        expect(plentiful_water.client_params[:chemicals]).to eql([:hydrogen, :oxygen])
        expect(plentiful_water.client_params[:ocean]).to be_true
        expect(plentiful_water.response_expectation_options[:salty]).to be_true
        expect(plentiful_water.response_expectation_options[:quantity]).to eql(infinity)

        expect(plentiful_fire.client_params[:reaction]).to eql(:combustion)
        expect(plentiful_fire.response_expectation_options[:body]).to eql(:hot_light)
        expect(plentiful_fire.client_params[:height]).to eql(infinity)

        expect(water_fire.client_params[:smoke]).to be_true
        expect(fire_water.client_params[:smoke]).to be_true

        expect(plentiful_fire_water.client_params[:chemicals]).to be_nil
        expect(plentiful_fire_water.client_params[:reaction]).to be_nil
        expect(plentiful_fire_water.client_params[:smoke]).to be_true
        expect(plentiful_fire_water.response_expectation_options[:body]).to be_nil
        expect(plentiful_fire_water.response_expectation_options[:quantity]).to eql(negative_infinity)
        expect(plentiful_fire_water.response_expectation_options[:salty]).to be_true
      end
    end
  end
end
