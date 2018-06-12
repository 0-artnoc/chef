# Author:: Tor Magnus Rakvåg (tm@intility.no)
# Copyright:: 2018, Intility AS
# License:: Apache License, Version 2.0
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

class Chef
  class Resource
    class PowershellPackageSource < Chef::Resource
      resource_name "powershell_package_source"
      provides(:powershell_package_source) { true }

      description "Use the powershell_package_source resource to register a powershell package repository"
      introduced "15.0"

      property :name, String,
               description: "",
               name_property: true

      property :url, String,
               description: "",
               required: true

      property :trusted, [true, false],
               description: "",
               default: false

      property :provider_name, String,
               equal_to: %w{ Programs msi NuGet msu PowerShellGet psl chocolatey },
               validation_message: "The following providers are supported: 'Programs', 'msi', 'NuGet', 'msu', 'PowerShellGet', 'psl' or 'chocolatey'",
               description: "",
               default: "NuGet"

      property :publish_location, String,
               description: "",
               required: false

      property :script_source_location, String,
               description: "",
               required: false

      property :script_publish_location, String,
               description: "",
               required: false

      load_current_value do
        cmd = load_resource_state_script(name)
        repo = powershell_out!(cmd)
        status = {}
        repo.stdout.split(/\r\n/).each do |line|
          kv = line.strip.split(/\s*:\s*/, 2)
          status[kv[0]] = kv[1] if kv.length == 2
        end
        url status["url"].nil? ? "not_set" : status["url"]
        trusted (status["trusted"] == "True" ? true : false)
        provider_name status["provider_name"]
        publish_location status["publish_location"]
        script_source_location status["script_source_location"]
        script_publish_location status["script_publish_location"]
      end

      action :register do
        # TODO: Ensure package provider is installed?
        if psrepository_cmdlet_appropriate?
          if package_source_exists?
            converge_if_changed :url, :trusted, :publish_location, :script_source_location, :script_publish_location do
              update_cmd = build_ps_repository_command("Set", new_resource)
              res = powershell_out(update_cmd)
              raise "Failed to update #{new_resource.name}: #{res.stderr}" unless res.stderr.empty?
            end
          else
            converge_by("register source: #{new_resource.name}") do
              register_cmd = build_ps_repository_command("Register", new_resource)
              res = powershell_out(register_cmd)
              raise "Failed to register #{new_resource.name}: #{res.stderr}" unless res.stderr.empty?
            end
          end
        else
          if package_source_exists?
            converge_if_changed :url, :trusted, :provider_name do
              update_cmd = build_package_source_command("Set", new_resource)
              res = powershell_out(update_cmd)
              raise "Failed to update #{new_resource.name}: #{res.stderr}" unless res.stderr.empty?
            end
          else
            converge_by("register source: #{new_resource.name}") do
              register_cmd = build_package_source_command("Register", new_resource)
              res = powershell_out(register_cmd)
              raise "Failed to register #{new_resource.name}: #{res.stderr}" unless res.stderr.empty?
            end
          end
        end
      end

      action :unregister do
        if package_source_exists?
          unregister_cmd = "Get-PackageSource -Name '#{new_resource.name}' | Unregister-PackageSource"
          converge_by("unregister source: #{new_resource.name}") do
            res = powershell_out(unregister_cmd)
            raise "Failed to unregister #{new_resource.name}: #{res.stderr}" unless res.stderr.empty?
          end
        end
      end

      action_class do
        def package_source_exists?
          cmd = powershell_out!("(Get-PackageSource -Name '#{new_resource.name}').Name")
          cmd.stdout.downcase.strip == new_resource.name.downcase
        end

        def psrepository_cmdlet_appropriate?
          new_resource.provider_name == "PowerShellGet"
        end

        def build_ps_repository_command(cmdlet_type, new_resource)
          cmd = "#{cmdlet_type}-PSRepository -Name '#{new_resource.name}'"
          cmd << " -SourceLocation '#{new_resource.url}'" if new_resource.url
          cmd << " -InstallationPolicy '#{new_resource.trusted ? "Trusted" : "Untrusted"}'"
          cmd << " -PublishLocation '#{new_resource.publish_location}'" if new_resource.publish_location
          cmd << " -ScriptSourceLocation '#{new_resource.script_source_location}'" if new_resource.script_source_location
          cmd << " -ScriptPublishLocation '#{new_resource.script_publish_location}'" if new_resource.script_publish_location
          cmd
        end

        def build_package_source_command(cmdlet_type, new_resource)
          cmd = "#{cmdlet_type}-PackageSource -Name '#{new_resource.name}'"
          cmd << " -Location '#{new_resource.url}'" if new_resource.url
          cmd << " -Trusted:#{new_resource.trusted ? "$true" : "$false"}"
          cmd << " -ProviderName '#{new_resource.provider_name}'" if new_resource.provider_name
          cmd
        end
      end
    end

    private

    def load_resource_state_script(name)
      <<-EOH
        if ((Get-PackageSource -Name '#{name}' -ErrorAction SilentlyContinue).ProviderName -eq 'PowerShellGet') {
            (Get-PSRepository -Name '#{name}') | Select @{n='name';e={$_.Name}}, @{n='url';e={$_.SourceLocation}},
            @{n='trusted';e={$_.Trusted}}, @{n='provider_name';e={$_.PackageManagementProvider}}, @{n='publish_location';e={$_.PublishLocation}},
            @{n='script_source_location';e={$_.ScriptSourceLocation}}, @{n='script_publish_location';e={$_.ScriptPublishLocation}} | fl
        }
        else {
            (Get-PackageSource -Name '#{name}'-ErrorAction SilentlyContinue) | Select @{n='name';e={$_.Name}}, @{n='url';e={$_.Location}},
            @{n='provider_name';e={$_.ProviderName}}, @{n='trusted';e={$_.IsTrusted}} | fl
        }
      EOH
    end
  end
end
