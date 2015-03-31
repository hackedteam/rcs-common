require 'spec_helper'
require 'stringio'
require 'rcs-common/updater/client'
require 'rcs-common/updater/server'

module RCS::Updater

  describe 'client' do
    before do
      allow_any_instance_of(Client).to receive(:trace).and_return(nil)
    end

    let(:signature) { '2433e2d6865e4e9a15ee57f74a196477' }

    let(:signature2) { '2433e2d6865e4e9a15ee57f74a196400' }

    let(:client) { Client.new("localhost") }

    before do
      @server_process_pid = fork do
        allow_any_instance_of(SharedKey).to receive(:read_key_from_file).and_return(signature)
        $stdout = StringIO.new
        $stderr = $stdout
        Server.start
      end

      # Wait for the server to bind
      sleep(2)

      allow(client).to receive(:localhost?).and_return(false)
    end

    after do
      Process.kill(9, @server_process_pid)
    end

    context 'when shared key is valid' do
      before do
        allow_any_instance_of(SharedKey).to receive(:read_key_from_file).and_return(signature)
      end

      it 'communicates' do
        expect(client.connected?).to be_truthy
      end
    end

    context 'when shared key is not valid' do
      before do
        allow_any_instance_of(SharedKey).to receive(:read_key_from_file).and_return(signature2)
      end

      it 'does not get a reply' do
        expect(client.connected?).to be_falsey
      end
    end

    context 'when requesting to execute an invalid command' do
      before do
        allow_any_instance_of(SharedKey).to receive(:read_key_from_file).and_return(signature)
      end

      it 'raises an error' do
        client.max_retries = 0
        expect { client.request("xpas123Mnq1", exec: 1) }.to raise_error
      end
    end

    context 'when requesting to execute the hostname command' do
      before do
        allow_any_instance_of(SharedKey).to receive(:read_key_from_file).and_return(signature)
      end

      it 'gets a valid response' do
        resp = client.request("hostname", exec: 1)
        expect(resp[:return_code]).to eq(0)
        expect(resp[:output]).to eq(`hostname`)
      end
    end
  end
end
