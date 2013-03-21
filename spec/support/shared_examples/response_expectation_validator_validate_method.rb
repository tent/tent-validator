shared_examples "a response expectation validator #validate method" do
  it "sets assertions" do
    expect(res[:assertions].to_a.sort_by { |h| h[:path] }).to eql(expected_assertions.sort_by { |h| h[:path] })
  end

  it "sets empty diff" do
    expect(res[:diff]).to eql(expected_diff)
  end

  it "sets failed assertions" do
    expect(res[:failed_assertions]).to eql(expected_failed_assertions)
  end

  it "sets valid flag" do
    expect(res[:valid]).to eql(expected_diff.empty?)
  end
end
