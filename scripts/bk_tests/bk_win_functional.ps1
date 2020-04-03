echo "--- system details"
$Properties = 'Caption', 'CSName', 'Version', 'BuildType', 'OSArchitecture'
Get-CimInstance Win32_OperatingSystem | Select-Object $Properties | Format-Table -AutoSize

# chocolatey functional tests fail so delete the chocolatey binary to avoid triggering them
Remove-Item -Path C:\ProgramData\chocolatey\bin\choco.exe -ErrorAction SilentlyContinue

echo "--- install ruby + devkit"
$ErrorActionPreference = 'Stop'

echo "Downloading Ruby + DevKit"
aws s3 cp s3://public-cd-buildkite-cache/rubyinstaller-devkit-2.6.5-1-x64.exe $env:temp/rubyinstaller-devkit-2.6.5-1-x64.exe

echo "Installing Ruby + DevKit"
Start-Process $env:temp\rubyinstaller-devkit-2.6.5-1-x64.exe -ArgumentList '/verysilent /dir=C:\\ruby26' -Wait

echo "Cleaning up installation"
Remove-Item $env:temp\rubyinstaller-devkit-2.6.5-1-x64.exe -Force -ErrorAction SilentlyContinue
echo "Closing out the layer (this can take awhile)"

# Set-Item -Path Env:Path -Value to include ruby26
$Env:Path+=";C:\ruby26\bin"

echo "--- configure winrm"

winrm quickconfig -q

echo "--- update bundler and rubygems"

ruby -v

$env:RUBYGEMS_VERSION=$(findstr rubygems omnibus_overrides.rb | %{ $_.split(" ")[3] })
$env:BUNDLER_VERSION=$(findstr bundler omnibus_overrides.rb | %{ $_.split(" ")[3] })

$env:RUBYGEMS_VERSION=($env:RUBYGEMS_VERSION -replace '"', "")
$env:BUNDLER_VERSION=($env:BUNDLER_VERSION -replace '"', "")

echo $env:RUBYGEMS_VERSION
echo $env:BUNDLER_VERSION

gem update --system $env:RUBYGEMS_VERSION
gem --version
gem install bundler -v $env:BUNDLER_VERSION --force --no-document --quiet
bundle --version

echo "--- bundle install"
bundle install --jobs=3 --retry=3 --without omnibus_package docgen chefstyle

echo "+++ bundle exec rake spec:functional"
bundle exec rake spec:functional

exit $LASTEXITCODE
