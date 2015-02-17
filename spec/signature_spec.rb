require 'spec_helper'
require 'rcs-common/signature'

class TestSignature
  include Mongoid::Document
  include RCS::Mongoid::Signature

  field :name, type: String
  field :surname, type: String
  field :code, type: Integer
  field :address, type: String
  field :complex, type: Hash

  sign_options :include => [:name, :surname, :code, :complex]
end

describe RCS::Mongoid::Signature do

  describe '.included' do

    let(:test) do
      TestSignature.new
    end

    let(:fields) do
      TestSignature.fields
    end

    before do
      test.run_callbacks(:create)
      test.run_callbacks(:save)
    end

    it "adds signature to the document" do
      expect(fields["signature"]).to_not be_nil
    end

  end

  context "when the document is created" do

    let(:test) do
      TestSignature.create(name: 'a', surname: 'b')
    end

    it "runs the created callbacks" do
      expect(test.signature).to_not be_nil
    end

    it 'validates the signature' do
      expect(test.check_signature).to be_truthy
    end

  end

  context 'when the document is updated' do

    let(:test) do
      TestSignature.create(name: 'a', surname: 'b', code: 123, complex: {a:1, b:2})
    end

    it 'validates the signature after reload' do
      test.reload
      expect(test.check_signature).to be_truthy
    end

    it 'validates the signature after save' do
      test.name = 'modified'
      test.save
      test.reload
      expect(test.check_signature).to be_truthy
    end

    it 'validates the signature after update_attributes' do
      test.update_attributes({surname: 'modified'})
      test.reload
      expect(test.check_signature).to be_truthy
    end

  end

  context 'when the document is tampered' do

    let(:test) do
      TestSignature.create(name: 'a', surname: 'b', code: 123, complex: {a:1, b:2})
    end

    it 'validate the signature when changing not included field' do
      test.address = 'c'
      expect(test.check_signature).to be_truthy
    end

    it 'invalidate the signature when changing a signed field' do
      test.name = 'mod'
      expect(test.check_signature).to be_falsey
    end

    it 'invalidate the signature when changing the signature itself' do
      test.signature = 'mod'
      expect(test.check_signature).to be_falsey
    end

  end

end
