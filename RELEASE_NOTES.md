_This file holds "in progress" release notes for the current release under development and is intended for consumption by the Chef Documentation team. Please see <https://docs.chef.io/release_notes.html> for the official Chef release notes._

# Chef Client Release Notes 12.18:

## Highlighted enhancements for this release:

- You can now specify the acceptable return codes from the chocolatey_package resource using the returns property.
- You can now enable chef-client to run as a scheduled task directly from the client MSI on Windows hosts.
- The package provider now supports DNF packages for Fedora and upcoming RHEL releases

## Highlighted bug fixes for this release:

- Fixed exposure of sensitive data of resources marked as sensitive inside Reporting. Before you were able to see the sensitive data on the Run History tab in the Chef Manage Console. Now we are sending a new blank resource if the resource is marked as sensitive, this way we will not compromise any sensitive data.

  _Note: Old data that was already sent to Reporting marked as sensitive will continue to be displayed. Apologies._

## New deprecations introduced in this release:

### Chef::Platform Helper Methods

- **Deprecation ID**: 13
- **Remediation Docs**: <https://docs.chef.io/deprecations_chef_platform_methods.html>
- **Expected Removal**: Chef 13 (April 2017)

### run_command Helper Method

- **Deprecation ID**: 14
- **Remediation Docs**: <https://docs.chef.io/deprecations_run_command.html>
- **Expected Removal**: Chef 13 (April 2017)
