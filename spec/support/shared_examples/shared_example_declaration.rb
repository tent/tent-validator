shared_examples "a shared example declaration" do
  it "gets added to shared example lookup" do
    name = "some shared example"
    block = lambda {}
    instance.shared_example(name, &block)
    expect(instance.shared_examples[name]).to eql(block)
  end
end
