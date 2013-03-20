shared_examples "shared example lookup" do
  it "returns block" do
    expect(instance.find_shared_example(name)).to eql(block)
  end
end
