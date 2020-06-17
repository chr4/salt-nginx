control 'letsencrypt' do
  title 'should be configured'

  for port in [80, 443] do
    describe port(port) do
      it { should be_listening }
      its('processes') { should include(/nginx/) }
    end
  end
end
