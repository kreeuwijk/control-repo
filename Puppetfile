#
forge 'http://forge.puppetlabs.com'

def default_branch(default)
  begin
    match = /(.+)_(cdpe|cdpe_ia)_\d+$/.match(@librarian.environment.name)
    match ? match[1]:default
  rescue
    default
  end
end

# Modules from the Puppet Forge
# Versions should be updated to be the latest at the time you start
mod 'puppetlabs-acl', '2.1.0'
mod 'puppetlabs-apache', '4.0.0'
mod 'puppetlabs-apt', '6.3.0'
mod 'puppetlabs-aws', '2.1.0'
mod 'puppetlabs-azure', '1.3.1'
mod 'puppetlabs-bolt_shim', '0.3.0'
mod 'puppetlabs-cd4pe', '1.4.1'
mod 'puppetlabs-cd4pe_jobs', '1.0.0'
mod 'puppetlabs-chocolatey', '3.3.0'
mod 'puppetlabs-cisco_ios', '1.0.0'
mod 'puppetlabs-ciscopuppet', '2.0.1'
mod 'puppetlabs-concat', '5.3.0'
mod 'puppetlabs-device_manager', '3.0.0'
mod 'puppetlabs-dism', '1.3.1'
mod 'puppetlabs-docker', '3.5.0'
mod 'puppetlabs-dsc_lite', '2.0.2'
mod 'puppetlabs-exec', '0.3.0'
mod 'puppetlabs-facter_task', '0.4.0'
mod 'puppetlabs-firewall', '2.1.0'
mod 'puppetlabs-gcc', '0.3.0'
mod 'puppetlabs-git', '0.5.0'
mod 'puppetlabs-haproxy', '3.0.1'
mod 'puppetlabs-hocon', '1.0.1'
mod 'puppetlabs-iis', '4.5.0'
mod 'puppetlabs-inifile', '2.5.0'
mod 'puppetlabs-java', '3.3.0'
mod 'puppetlabs-limits', '0.1.0'
mod 'puppetlabs-motd', '2.1.2'
mod 'puppetlabs-mount_iso', '2.0.0'
mod 'puppetlabs-mysql', '8.0.1'
mod 'puppetlabs-netdev_stdlib', '0.18.0'
mod 'puppetlabs-ntp', '7.4.0'
mod 'puppetlabs-panos', '1.2.1'
mod 'puppetlabs-pipelines', '1.0.0'
mod 'puppetlabs-powershell', '2.2.0'
mod 'puppetlabs-puppet_agent', '2.2.2'
mod 'puppetlabs-puppet_authorization', '0.5.0'
mod 'puppetlabs-puppetserver_gem', '1.1.1'
mod 'puppetlabs-reboot', '2.1.2'
mod 'puppetlabs-registry', '2.1.0'
mod 'puppetlabs-resource', '0.1.0'
mod 'puppetlabs-resource_api', '1.1.0'
mod 'puppetlabs-service', '0.5.0'
mod 'puppetlabs-splunk_hec', '0.6.0'
mod 'puppetlabs-sqlserver', '2.4.0'
mod 'puppetlabs-stdlib', '5.2.0'
mod 'puppetlabs-tomcat', '2.5.0'
mod 'puppetlabs-transition', '0.1.1'
mod 'puppetlabs-translate', '1.2.0'
mod 'puppetlabs-vcsrepo', '2.4.0'

# Forge Community Modules
mod 'saz-timezone', '5.1.1'
mod 'jpi-timezone_win', '0.1.6'
mod 'geoffwilliams-windows_firewall', '0.3.0'

mod 'WhatsARanjit-node_manager', '0.7.1'
mod 'ghoneycutt-ssh', '3.59.0'
mod 'herculesteam-augeasproviders_core', '2.4.0'
mod 'herculesteam-augeasproviders_ssh', '3.2.1'
mod 'herculesteam-augeasproviders_sysctl', '2.3.1'
mod 'puppet-selinux', '1.6.1'
mod 'puppet-nginx', '0.16.0'
mod 'puppet-archive', '4.4.0'
mod 'puppet-windows_env', '3.2.0'
mod 'puppet-windowsfeature', '3.2.2'
mod 'stahnma-epel', '1.3.1'
mod 'puppet-python', '2.2.2'
mod 'thias-sysctl', '1.0.6'
mod 'jdowning-rbenv', '2.4.0'
mod 'tkishel-system_gem', '1.1.1'
mod 'puppetlabs-yumrepo_core', '1.0.3'
mod 'puppetlabs-sshkeys_core', '1.0.2'
mod 'puppetlabs-selinux_core', '1.0.2'
mod 'puppetlabs-augeas_core', '1.0.4'
mod 'puppetlabs-host_core', '1.0.2'

mod 'servicenow_integration', # not published on the forge
  :git    => 'https://github.com/kreeuwijk/puppetlabs-servicenow_integration.git',
  :branch => 'master'
