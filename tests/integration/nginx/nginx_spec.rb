control 'nginx' do
  title 'should be installed & configured'

  describe file('/etc/apt/sources.list.d/nginx.list') do
    its('content') { should match /^deb http:\/\/nginx.org\/packages\/mainline\/ubuntu / }
  end

  describe package('nginx') do
    it { should be_installed }
    its('version') { should cmp >= '1.17.10' }
  end

  describe file('/etc/nginx/nginx.conf') do
    its('mode') { should cmp '0644' }
    its('content') { should match /^\s*worker_processes/ }
    its('content') { should match /^\s*ssl_prefer_server_ciphers:\s*on;$/ }
  end

  describe file('/etc/nginx/conf.d/default.conf') do
    it { should_not exist }
  end

  describe service('nginx') do
    it { should be_enabled }
    it { should be_running }
  end
end
