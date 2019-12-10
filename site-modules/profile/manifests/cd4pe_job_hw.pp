# Installs prereqs for CD4PE Job Hardware
class profile::cd4pe_job_hw {

    class { 'docker':
      version => 'latest',
    }

    package { 'git':
      ensure => latest
    }
}
