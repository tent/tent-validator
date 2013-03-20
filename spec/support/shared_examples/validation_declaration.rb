shared_examples "a validation declaration" do
  it "sets name" do
    name = "some validation"
    options = Hash.new
    validation = instance.send(method_name, name, options)
    expect(validation.name).to eql(name)
  end

  it "references parent" do
    options = Hash.new
    validation = instance.send(method_name, "some validation", options)
    expect(validation.parent).to eql(parent)
  end

  it "gets appended to list of validations" do
    options = Hash.new
    validation = instance.send(method_name, "some validation", options)
    expect(instance.validations.last).to eql(validation)
  end

  it "calls block in scope of validation" do
    ref = nil
    options, block = Hash.new, proc { ref = self }
    validation = instance.send(method_name, "some validation with block", options, &block)
    expect(ref).to eql(validation)
  end

  context "when no block given" do
    it "sets pending flag" do
      options = {}
      validation = instance.send(method_name, "some validation without block", options)
      expect(validation.pending).to be_true
    end
  end

  context "when before hook specified" do
    context "when before hook is a method name" do
      it "appends method reference to before hooks list" do
        before_hook_method_name = :some_random_method

        described_class.class_eval do
          define_method before_hook_method_name do
          end
        end

        options = { :before => before_hook_method_name }
        validation = instance.send(method_name, "some validation with before hook", options)

        expect(validation.before_hooks.last.name).to eql(before_hook_method_name)
        expect(validation.before_hooks.last).to respond_to(:call)
      end
    end

    context "when before hook is a block" do
      it "appends block to before hooks list" do
        before_hook = lambda {}

        options = { :before => before_hook }
        validation = instance.send(method_name, "some validation with before hook", options)

        expect(validation.before_hooks.last).to eql(before_hook)
      end
    end
  end
end
