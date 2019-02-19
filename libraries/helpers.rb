#
# Cookbook:: mariadb
# Library:: helpers
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

module MariaDBCookbook
  module Helpers
    include Chef::Mixin::ShellOut

    require 'securerandom'

    #######
    # Function to execute an SQL statement
    #   Input:
    #     query : Query could be a single String or an Array of String.
    #     database : a string containing the name of the database to query in, nil if no database choosen
    #     ctrl : a Hash which could contain:
    #        - user : String or nil
    #        - password : String or nil
    #        - host : String or nil
    #        - port : String or Integer or nil
    #        - socket : String or nil
    #   Output: A String with cmd to execute the query (but do not execute it!)
    #
    def sql_command_string(query, database, ctrl, grep_for = nil)
      raw_query = query.is_a?(String) ? query : query.join(";\n")
      Chef::Log.debug("Control Hash: [#{ctrl.to_json}]\n")
      cmd = "/usr/bin/mysql -B -e \"#{raw_query}\""
      cmd << " --user=#{ctrl[:user]}" if ctrl && ctrl.key?(:user) && !ctrl[:user].nil?
      cmd << " -p#{ctrl[:password]}"  if ctrl && ctrl.key?(:password) && !ctrl[:password].nil?
      cmd << " -h #{ctrl[:host]}"     if ctrl && ctrl.key?(:host) && !ctrl[:host].nil? && ctrl[:host] != 'localhost'
      cmd << " -P #{ctrl[:port]}"     if ctrl && ctrl.key?(:port) && !ctrl[:port].nil? && ctrl[:host] != 'localhost'
      cmd << " -S #{ctrl[:socket]}"   if ctrl && ctrl.key?(:socket) && !ctrl[:socket].nil?
      cmd << " #{database}"            unless database.nil?
      cmd << " | grep #{grep_for}"     if grep_for
      Chef::Log.debug("Executing this command: [#{cmd}]\n")
      cmd
    end

    #######
    # Function to execute an SQL statement in the default database.
    #   Input: Query could be a single String or an Array of String.
    #   Output: A String with <TAB>-separated columns and \n-separated rows.
    # This is easiest for 1-field (1-row, 1-col) results, otherwise
    # it will be complex to parse the results.
    def execute_sql(query, db_name, ctrl)
      cmd = shell_out(sql_command_string(query, db_name, ctrl),
                      user: 'root')
      if cmd.exitstatus != 0
        Chef::Log.fatal("mysql failed executing this SQL statement:\n#{query}")
        Chef::Log.fatal(cmd.stderr)
        raise 'SQL ERROR'
      end
      cmd.stdout
    end

    def parse_one_row(row, titles)
      return_hash = {}
      index = 0
      row.split("\t").each do |column|
        return_hash[titles[index]] = column
        index += 1
      end
      return_hash
    end

    def parse_mysql_batch_result(mysql_batch_result)
      results = mysql_batch_result.split("\n")
      titles = []
      index = 0
      return_array = []
      results.each do |row|
        if index == 0
          titles = row.split("\t")
        else
          return_array[index - 1] = parse_one_row(row, titles)
        end
        index += 1
      end
      return_array
    end

    def default_instance
      ''
    end

    def data_dir(instance)
      if instance && instance != ''
        "/var/lib/mysql-#{instance}"
      else
        '/var/lib/mysql'
      end
    end

    def conf_dir(instance)
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        '/etc'
      when 'debian'
        if instance && instance != ''
          "/etc/mysql-#{instance}"
        else
          '/etc/mysql'
        end
      end
    end

    def ext_conf_dir(instance)
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        "#{conf_dir(instance)}/my.cnf.d"
      when 'debian'
        "#{conf_dir(instance)}/conf.d"
      end
    end

    def log_dir(instance)
      if instance && instance != ''
        "/var/log/mysql-#{instance}"
      else
        '/var/log/mysql'
      end
    end

    # determine the platform specific service name
    def platform_service_name(instance)
      if instance && instance != ''
        "mariadb@#{instance}"
      else
        'mariadb'
      end
    end

    def mysql_command_string(database, query)
      "psql -d #{database} <<< '#{query};'"
    end

    def slave?
      ::File.exist? "#{data_dir}/recovery.conf"
    end

    def initialized?
      return true if ::File.exist?("#{conf_dir}/my.cnf")
      false
    end

    def secure_random
      r = SecureRandom.hex
      Chef::Log.debug "Generated password: #{r}"
      r
    end

    # determine the platform specific server package name
    def server_pkg_name
      platform_family?('debian') ? "mariadb-server-#{new_resource.version}" : 'MariaDB-server'
    end

    # given the base URL build the complete URL string for a yum repo
    def yum_repo_url(base_url)
      "#{base_url}/#{new_resource.version}/#{yum_repo_platform_string}"
    end

    # build the platform string that makes up the final component of the yum repo URL
    def yum_repo_platform_string
      release = yum_releasever
      "#{node['platform']}#{release}-#{node['kernel']['machine'] == 'x86_64' ? 'amd64' : '$basearch'}"
    end

    # on amazon use the RHEL 6 packages. Otherwise use the releasever yum variable
    def yum_releasever
      platform?('amazon') ? '6' : '$releasever'
    end

    def default_socket(instance)
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        '/var/lib/mysql/mysql.sock'
      when 'debian'
        if instance && instance != ''
          "/var/run/mysqld/mysqld-#{instance}.sock"
        else
          '/var/run/mysqld/mysqld.sock'
        end
      end
    end

    def default_pid_file(instance)
      case node['platform_family']
      when 'rhel', 'fedora', 'amazon'
        nil
      when 'debian'
        if instance && instance != ''
          "/var/run/mysqld/mysqld-#{instance}.pid"
        else
          '/var/run/mysqld/mysqld.pid'
        end
      end
    end

  end
end
