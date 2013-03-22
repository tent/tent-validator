require 'spec_helper'
require 'support/shared_examples/validation_declaration'
require 'support/shared_examples/shared_example_declaration'
require 'support/shared_examples/shared_example_lookup'

describe TentValidator::Validator do
  describe "class methods" do
    let(:instance) { described_class }

    describe ".describe" do
      it_behaves_like "a validation declaration" do
        let(:method_name) { :describe }
        let(:parent) { nil }
      end
    end

    describe ".context" do
      it_behaves_like "a validation declaration" do
        let(:method_name) { :describe }
        let(:parent) { nil }
      end
    end

    describe ".shared_example" do
      it_behaves_like "a shared example declaration"
    end
  end

  describe "instance methods" do
    let(:instance) { described_class.new("foo bar") }

    describe "#describe" do
      it_behaves_like "a validation declaration" do
        let(:method_name) { :describe }
        let(:parent) { instance }
      end
    end

    describe "#context" do
      it_behaves_like "a validation declaration" do
        let(:method_name) { :context }
        let(:parent) { instance }
      end
    end

    describe "#shared_example" do
      it_behaves_like "a shared example declaration"
    end

    describe "#find_shared_example" do
      let(:block) { lambda {} }
      let(:name) { :foo }

      context "when example in current instance" do
        before do
          instance.shared_examples[name] = block
        end

        it_behaves_like "shared example lookup"
      end

      context "when example in parent instance" do
        before do
          i = described_class.new("bar baz")
          instance.instance_eval { @parent = i }
          i.shared_examples[name] = block
        end

        it_behaves_like "shared example lookup"
      end

      context "when example in parent of parent instance" do
        before do
          i = described_class.new("bar bar")
          instance.instance_eval { @parent = i }

          i2 = described_class.new("baz biz")
          i.instance_eval { @parent = i2 }

          i2.shared_examples[name] = block
        end

        it_behaves_like "shared example lookup"
      end

      context "when example in class" do
        before do
          described_class.shared_examples[name] = block
        end

        it_behaves_like "shared example lookup"
      end
    end

    describe "#behaves_as" do
      let(:name) { :bar }

      context "when shared example exists" do
        it "calls block in scope of validator" do
          ref = nil
          example_block = proc { ref = self }

          instance.stubs(:find_shared_example).with(name).returns(example_block)
          instance.behaves_as(name)

          expect(ref).to eql(instance)
        end
      end

      context "when shared example does not exist" do
        it "raises BehaviourNotFoundError" do
          expect { instance.behaves_as(name) }.to raise_error(TentValidator::Validator::BehaviourNotFoundError)
        end
      end
    end

    describe "#expect_response" do
      it "creates a new response expectation" do
        expect(instance.expect_response).to be_a(TentValidator::ResponseExpectation)
      end

      it "appends expectation to list of expectations" do
        expect { instance.expect_response }.to change(instance.expectations, :size).by(1)
      end
    end

    describe "#run" do
      it "calls before hooks in context of validator" do
        ref = nil
        before_hook = proc { ref = self }
        instance.before_hooks << before_hook

        instance.run
        expect(ref).to eql(instance)
      end

      context "when before hook is an instance method" do
        it "calls before hooks in context of validator" do
          ref = nil
          instance.class.class_eval do
            define_method :something do
              ref = self
            end
          end
          instance.before_hooks << instance.method(:something)

          instance.run
          expect(ref).to eql(instance)
        end
      end

      it "executes response expectations" do
        response_expectation = stub
        instance.expectations << response_expectation

        response_expectation.expects(:run).returns([])
        instance.run
      end

      it "runs child validations" do
        child = stub
        instance.validations << child

        child.expects(:run).returns(stub(:results => {}))
        instance.run
      end

      it "returns validator results object" do
        child = described_class.new("biz baz")
        instance.validations << child

        child.stubs(:run).returns(stub(
          :results => {
            "biz baz" => {
              :results => [
                { :response_headers => { :valid => true } }
              ]
            }
          }
        ))

        res = instance.run
        expect(res.as_json).to eql(
          instance.name => {
            :results => [],
            child.name => {
              :results => [
                { :response_headers => { :valid => true } }
              ]
            }
          }
        )
      end
    end
  end
end
