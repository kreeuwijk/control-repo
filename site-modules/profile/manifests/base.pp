# class profile::base
# Manages baseline settings

class profile::base {

  $agentruninterval = lookup('puppet_agent_run_interval')
  $agentversion = lookup('puppet_agent_version')

  if versioncmp($facts['aio_agent_version'],$agentversion) == -1 {
    class { 'puppet_agent':
      package_version => $agentversion
    }
  }

  @@host { $trusted['certname'] :
    ensure => 'present',
    ip     => $facts['ipaddress']
  }

  Host <<| |>>

  ini_setting {
    default:
      ensure            => present,
      section           => 'main',
      key_val_separator => '=',
      path              => $facts['puppet_config'],
      notify            => Service['puppet'],
    ;
    'puppet[main:runinterval]':
      setting => 'runinterval',
      value   => $agentruninterval,
    ;
    'puppet[main:priority]':
      setting => 'priority',
      value   => 'low',
    ;
    'puppet[main:usecacheonfailure]':
      setting => 'usecacheonfailure',
      value   => true,
    ;
    'puppet[main:splay]':
      setting => 'splay',
      value   => false,
  }

  service { 'puppet':
    ensure => running
  }

  case $::osfamily {
    default: { } # for OS's not listed, do nothing
    'RedHat': {
      $timezone = lookup('timezone.linux')
      class { 'timezone':
        timezone => $timezone,
      }
      ini_setting { 'yum[main:installonly_limit]':
        ensure            => present,
        section           => 'main',
        setting           => 'installonly_limit',
        key_val_separator => '=',
        value             => '2',
        path              => '/etc/yum.conf',
        notify            => Service['puppet']
      }
    }
    'windows': {
      $timezone = lookup('timezone.windows')
      class { 'timezone_win':
        timezone => $timezone,
      }
      pspackageprovider {'Nuget':
        ensure   => 'present',
      }
      psrepository { 'PSGallery':
        ensure              => present,
        source_location     => 'https://www.powershellgallery.com/api/v2',
        installation_policy => 'untrusted',
      }
      reboot { 'dsc_reboot':
        when   => 'pending',
        onlyif => 'pending_dsc_reboot'
      }
      registry_key { 'Windows Defender Policy':
        ensure => present,
        path   => 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
      }
      registry_value {
        default:
          ensure => present,
          type   => 'dword',
        ;
        'Disable Windows Defender':
          path => 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\DisableAntiSpyware',
          data => 1,
        ;
        'Enable RDP':
          path => 'HKLM\System\CurrentControlSet\Control\Terminal Server\fDenyTSConnections',
          data => 0
      }
      windows_firewall_group { 'Remote Desktop':
        enabled => true,
      }
      windows_firewall_rule { 'File and Printer Sharing (Echo Request - ICMPv4-In)':
        ensure        => present,
        action        => 'allow', #allow/block
        icmp_type     => '8',
        protocol      => 'icmpv4',
        description   => 'Echo Request messages are sent as ping requests to other nodes.',
        display_group => 'File and Printer Sharing',
      }
    }
  }

}
