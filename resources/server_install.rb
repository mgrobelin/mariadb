# frozen_string_literal: true
#
# Cookbook:: mariadb
# Resource:: server_install
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include MariaDBCookbook::Helpers

property :version,           String,        default: '10.3'
property :instance,          String,        default: lazy { default_instance }
# for systemd mariadb@.service unit template
property :cookbook,          String,        default: 'mariadb'
property :setup_repo,        [true, false], default: true
property :mycnf_file,        String,        default: lazy { "#{conf_dir(instance)}/my.cnf" }
property :extconf_directory, String,        default: lazy { ext_conf_dir(instance) }
property :data_directory,    String,        default: lazy { data_dir(instance) }
property :external_pid_file, String,        default: lazy { "/var/run/mysql/#{version}-main.pid" }

action :install do
  node.run_state['mariadb'] ||= {}
  node.run_state['mariadb']['version'] = new_resource.version

  mariadb_client_install 'Install MariaDB Client' do
    version new_resource.version
    setup_repo new_resource.setup_repo
  end

  package server_pkg_name

  # The default systemd unit expects configuration within /etc/mysql/conf.d/my%I.cnf (where %I is the instance name),
  # but we favor /etc/mysql-%I/my.cnf instead
  template '/etc/systemd/system/mariadb@.service' do
    source 'systemd/mariadb@.service.erb'
    owner 'root'
    group 'root'
    mode '0644'
    cookbook new_resource.cookbook
    variables(
      instance: new_resource.instance,
      cnf_file: new_resource.mycnf_file
    )
  end

  # Link resolveip as MariaDB mysql_install_db otherwise complains https://jira.mariadb.org/browse/MDEV-18563
  if node['platform'] == 'ubuntu'
    link '/usr/sbin/resolveip' do
      to '/usr/bin/resolveip'
      #only_if 'test -f /usr/bin/resolveip'
      #not_if 'test -L /usr/sbin/resolveip || test -f /usr/sbin/resolveip'
    end
  end
end

action_class do
  include MariaDBCookbook::Helpers
end
