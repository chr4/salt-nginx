control 'nginx-unit' do
  title 'should be installed & configured'

  describe file('/etc/apt/sources.list.d/nginx-unit.list') do
    its('content') { should match /^deb https:\/\/packages.nginx.org\/unit\/ubuntu/ }
  end

  describe package('unit-php') do
    it { should be_installed }
  end

  describe service('unit') do
    it { should be_enabled }
    it { should be_running }
  end
end
